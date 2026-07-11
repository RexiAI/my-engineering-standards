//go:build ignore
// +build ignore

// go-saga-lint — static analysis for Saga and Outbox pattern enforcement.
//
// Standards reference:
//   docs/SAGA_PATTERN.md
//   docs/OUTBOX_PATTERN.md
//
// Usage (copy this file into the child project and run):
//
//   go run .standards/ci/templates/go-saga-lint.go ./...
//
// Or wire into CI (see ci/gitlab/backend/ci-go.yml):
//
//   go run "${STANDARDS_DIR}/ci/templates/go-saga-lint.go" ./...
//
// Exit codes:
//   0 — no violations
//   1 — violations found (CI gate fails)
//
// Checks performed:
//   1. Every *SagaHandler function must have a sibling *Compensate function in the same package.
//   2. Outbox inserts must co-locate with business writes (same function contains both).
//   3. Functions matching *SagaHandler must accept or derive a context.Context (for timeout).
//
// Conventions assumed:
//   - Saga handler functions: name ends with "SagaHandler" (e.g., ProcessPaymentSagaHandler)
//   - Compensation functions: name ends with "Compensate" (e.g., ProcessPaymentCompensate)
//   - Outbox inserts: call to function/method containing "InsertOutbox", "SaveOutbox", or
//     assignment to variable/field named "outbox" within same function as business DB write.

package main

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"strings"
)

func main() {
	patterns := []string{"./..."}
	if len(os.Args) > 1 {
		patterns = os.Args[1:]
	}

	dirs, err := resolveDirs(patterns)
	if err != nil {
		fmt.Fprintf(os.Stderr, "go-saga-lint: failed to resolve paths: %v\n", err)
		os.Exit(1)
	}

	violations := 0
	for _, dir := range dirs {
		v, err := lintDir(dir)
		if err != nil {
			fmt.Fprintf(os.Stderr, "go-saga-lint: error scanning %s: %v\n", dir, err)
		}
		violations += v
	}

	if violations > 0 {
		fmt.Fprintf(os.Stderr, "\ngo-saga-lint: %d violation(s) found. Fix before merging.\n", violations)
		os.Exit(1)
	}
	fmt.Println("go-saga-lint: OK — no saga/outbox pattern violations found.")
}

// lintDir parses all .go files in a directory and runs all checks.
func lintDir(dir string) (int, error) {
	fset := token.NewFileSet()
	pkgs, err := parser.ParseDir(fset, dir, func(fi os.FileInfo) bool {
		return !strings.HasSuffix(fi.Name(), "_test.go")
	}, 0)
	if err != nil {
		// Non-fatal: may be a dir with no .go files
		return 0, nil
	}

	violations := 0
	for _, pkg := range pkgs {
		violations += checkCompensationPairs(fset, pkg)
		violations += checkOutboxCoLocation(fset, pkg)
		violations += checkSagaHandlerContext(fset, pkg)
	}
	return violations, nil
}

// checkCompensationPairs — Rule 1.
// Every function named *SagaHandler must have a sibling compensation function in the same package.
// Accepted compensation names (matching docs/SAGA_PATTERN.md §Compensating Transactions):
//   - {Base}Compensate      e.g. ProcessPaymentCompensate
//   - Rollback{Base}        e.g. RollbackProcessPayment
//   - rollback{Base}        e.g. rollbackProcessPayment
//   - On{Base}Failed        e.g. OnProcessPaymentFailed
//   - on{Base}Failed        e.g. onProcessPaymentFailed
func checkCompensationPairs(fset *token.FileSet, pkg *ast.Package) int {
	handlers := map[string]token.Position{}
	compensations := map[string]bool{}

	for _, file := range pkg.Files {
		for _, decl := range file.Decls {
			fn, ok := decl.(*ast.FuncDecl)
			if !ok {
				continue
			}
			name := fn.Name.Name
			if strings.HasSuffix(name, "SagaHandler") {
				base := strings.TrimSuffix(name, "SagaHandler")
				handlers[base] = fset.Position(fn.Pos())
			}
			// Accept: {Base}Compensate
			if strings.HasSuffix(name, "Compensate") {
				base := strings.TrimSuffix(name, "Compensate")
				compensations[base] = true
			}
			// Accept: Rollback{Base} or rollback{Base}
			if strings.HasPrefix(name, "Rollback") || strings.HasPrefix(name, "rollback") {
				base := strings.TrimPrefix(strings.TrimPrefix(name, "Rollback"), "rollback")
				compensations[base] = true
				// also mark lower-cased base
				if len(base) > 0 {
					compensations[strings.ToLower(base[:1])+base[1:]] = true
					compensations[strings.ToUpper(base[:1])+base[1:]] = true
				}
			}
			// Accept: On{Base}Failed or on{Base}Failed
			if strings.HasSuffix(name, "Failed") {
				trimmed := strings.TrimSuffix(name, "Failed")
				base := strings.TrimPrefix(strings.TrimPrefix(trimmed, "On"), "on")
				if base != trimmed { // had On/on prefix
					compensations[base] = true
					if len(base) > 0 {
						compensations[strings.ToLower(base[:1])+base[1:]] = true
						compensations[strings.ToUpper(base[:1])+base[1:]] = true
					}
				}
			}
		}
	}

	violations := 0
	for base, pos := range handlers {
		if !compensations[base] {
			fmt.Fprintf(os.Stderr,
				"%s: saga violation: %sSagaHandler has no matching compensation function in package %s\n"+
					"  Expected one of: %sCompensate, Rollback%s, rollback%s, On%sFailed, on%sFailed\n"+
					"  See docs/SAGA_PATTERN.md §Compensating Transactions.\n",
				pos, base, pkg.Name, base, base, base, base, base)
			violations++
		}
	}
	return violations
}

// checkOutboxCoLocation — Rule 2.
// Functions that call InsertOutbox/SaveOutbox must also contain a DB write call
// (Insert/Save/Update/Exec) in the same function body — they must be co-located.
func checkOutboxCoLocation(fset *token.FileSet, pkg *ast.Package) int {
	violations := 0

	for _, file := range pkg.Files {
		for _, decl := range file.Decls {
			fn, ok := decl.(*ast.FuncDecl)
			if !ok || fn.Body == nil {
				continue
			}

			hasOutboxWrite := false
			hasBusinessWrite := false

			ast.Inspect(fn.Body, func(n ast.Node) bool {
				call, ok := n.(*ast.CallExpr)
				if !ok {
					return true
				}
				callName := extractCallName(call)
				if isOutboxCall(callName) {
					hasOutboxWrite = true
				}
				if isBusinessDBCall(callName) {
					hasBusinessWrite = true
				}
				return true
			})

			if hasOutboxWrite && !hasBusinessWrite {
				pos := fset.Position(fn.Pos())
				fmt.Fprintf(os.Stderr,
					"%s: outbox violation: function %s writes to outbox but no business DB write detected in same function\n"+
						"  Outbox inserts must be co-located with the business write in the same transaction.\n"+
						"  See docs/OUTBOX_PATTERN.md §Solution.\n",
					pos, fn.Name.Name)
				violations++
			}
		}
	}
	return violations
}

// checkSagaHandlerContext — Rule 3.
// Functions named *SagaHandler must accept a context.Context parameter (enables timeout).
func checkSagaHandlerContext(fset *token.FileSet, pkg *ast.Package) int {
	violations := 0

	for _, file := range pkg.Files {
		for _, decl := range file.Decls {
			fn, ok := decl.(*ast.FuncDecl)
			if !ok {
				continue
			}
			if !strings.HasSuffix(fn.Name.Name, "SagaHandler") {
				continue
			}

			hasContext := false
			if fn.Type.Params != nil {
				for _, param := range fn.Type.Params.List {
					if sel, ok := param.Type.(*ast.SelectorExpr); ok {
						if sel.Sel.Name == "Context" {
							hasContext = true
						}
					}
				}
			}

			if !hasContext {
				pos := fset.Position(fn.Pos())
				fmt.Fprintf(os.Stderr,
					"%s: saga violation: %s does not accept context.Context\n"+
						"  Saga handlers must accept context.Context to support timeout enforcement.\n"+
						"  See docs/SAGA_PATTERN.md §Saga Timeout.\n",
					pos, fn.Name.Name)
				violations++
			}
		}
	}
	return violations
}

// ── Helpers ──────────────────────────────────────────────────────────────────

func extractCallName(call *ast.CallExpr) string {
	switch fn := call.Fun.(type) {
	case *ast.Ident:
		return fn.Name
	case *ast.SelectorExpr:
		return fn.Sel.Name
	}
	return ""
}

func isOutboxCall(name string) bool {
	lower := strings.ToLower(name)
	return strings.Contains(lower, "outbox") &&
		(strings.Contains(lower, "insert") || strings.Contains(lower, "save") ||
			strings.Contains(lower, "create") || strings.Contains(lower, "write"))
}

func isBusinessDBCall(name string) bool {
	lower := strings.ToLower(name)
	// Common Go DB write patterns: Insert, Save, Create, Update, Exec, ExecContext
	for _, verb := range []string{"insert", "save", "create", "update", "exec", "upsert", "store"} {
		if strings.Contains(lower, verb) && !strings.Contains(lower, "outbox") {
			return true
		}
	}
	return false
}

func resolveDirs(patterns []string) ([]string, error) {
	dirs := []string{}
	seen := map[string]bool{}

	for _, pattern := range patterns {
		// Strip ./... suffix — walk from given root
		root := strings.TrimSuffix(pattern, "/...")
		root = strings.TrimSuffix(root, "...")

		err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return nil
			}
			if info.IsDir() {
				if strings.HasPrefix(info.Name(), ".") || info.Name() == "vendor" {
					return filepath.SkipDir
				}
				if !seen[path] {
					seen[path] = true
					dirs = append(dirs, path)
				}
			}
			return nil
		})
		if err != nil {
			return nil, err
		}
	}
	return dirs, nil
}
