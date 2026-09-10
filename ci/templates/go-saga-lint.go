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
			registerSagaHandler(fn.Name.Name, fset.Position(fn.Pos()), handlers)
			registerCompensation(fn.Name.Name, compensations)
		}
	}

	violations := 0
	for base, pos := range handlers {
		if !compensations[base] {
			reportMissingCompensation(pos, base, pkg.Name)
			violations++
		}
	}
	return violations
}

// registerSagaHandler records a *SagaHandler declaration's base name and position.
func registerSagaHandler(name string, pos token.Position, handlers map[string]token.Position) {
	if strings.HasSuffix(name, "SagaHandler") {
		handlers[strings.TrimSuffix(name, "SagaHandler")] = pos
	}
}

// registerCompensation records the accepted compensation-name forms of a declaration.
func registerCompensation(name string, compensations map[string]bool) {
	// Accept: {Base}Compensate
	if strings.HasSuffix(name, "Compensate") {
		compensations[strings.TrimSuffix(name, "Compensate")] = true
	}
	// Accept: Rollback{Base} or rollback{Base}
	if strings.HasPrefix(name, "Rollback") || strings.HasPrefix(name, "rollback") {
		markBaseVariants(compensations, strings.TrimPrefix(strings.TrimPrefix(name, "Rollback"), "rollback"))
	}
	// Accept: On{Base}Failed or on{Base}Failed
	if strings.HasSuffix(name, "Failed") {
		markFailedVariants(compensations, strings.TrimSuffix(name, "Failed"))
	}
}

// markFailedVariants registers an On{Base}Failed / on{Base}Failed form, if it is one.
func markFailedVariants(compensations map[string]bool, trimmed string) {
	base := strings.TrimPrefix(strings.TrimPrefix(trimmed, "On"), "on")
	if base == trimmed { // no On/on prefix — not an accepted form
		return
	}
	markBaseVariants(compensations, base)
}

// markBaseVariants registers a base name plus its first-letter case variants.
func markBaseVariants(compensations map[string]bool, base string) {
	compensations[base] = true
	if len(base) == 0 {
		return
	}
	compensations[strings.ToLower(base[:1])+base[1:]] = true
	compensations[strings.ToUpper(base[:1])+base[1:]] = true
}

// reportMissingCompensation emits the rule-1 finding for an uncompensated handler.
func reportMissingCompensation(pos token.Position, base, pkgName string) {
	fmt.Fprintf(os.Stderr,
		"%s: saga violation: %sSagaHandler has no matching compensation function in package %s\n"+
			"  Expected one of: %sCompensate, Rollback%s, rollback%s, On%sFailed, on%sFailed\n"+
			"  See docs/SAGA_PATTERN.md §Compensating Transactions.\n",
		pos, base, pkgName, base, base, base, base, base)
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
			violations += checkOutboxFunc(fset, fn)
		}
	}
	return violations
}

// checkOutboxFunc returns 1 when one function violates the co-location rule.
func checkOutboxFunc(fset *token.FileSet, fn *ast.FuncDecl) int {
	hasOutboxWrite, hasBusinessWrite := scanBodyWrites(fn)
	if hasOutboxWrite && !hasBusinessWrite {
		reportOutboxCoLocation(fset.Position(fn.Pos()), fn.Name.Name)
		return 1
	}
	return 0
}

// scanBodyWrites reports whether a function body contains an outbox write
// and/or a business DB write.
func scanBodyWrites(fn *ast.FuncDecl) (outbox, business bool) {
	ast.Inspect(fn.Body, func(n ast.Node) bool {
		call, ok := n.(*ast.CallExpr)
		if !ok {
			return true
		}
		callName := extractCallName(call)
		outbox = outbox || isOutboxCall(callName)
		business = business || isBusinessDBCall(callName)
		return true
	})
	return outbox, business
}

// reportOutboxCoLocation emits the rule-2 finding for a function.
func reportOutboxCoLocation(pos token.Position, name string) {
	fmt.Fprintf(os.Stderr,
		"%s: outbox violation: function %s writes to outbox but no business DB write detected in same function\n"+
			"  Outbox inserts must be co-located with the business write in the same transaction.\n"+
			"  See docs/OUTBOX_PATTERN.md §Solution.\n",
		pos, name)
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
			violations += checkSagaHandler(fset, fn)
		}
	}
	return violations
}

// checkSagaHandler returns 1 when one *SagaHandler function lacks a
// context.Context parameter.
func checkSagaHandler(fset *token.FileSet, fn *ast.FuncDecl) int {
	if !strings.HasSuffix(fn.Name.Name, "SagaHandler") {
		return 0
	}
	if acceptsContextParam(fn) {
		return 0
	}
	reportMissingContextParam(fset.Position(fn.Pos()), fn.Name.Name)
	return 1
}

// acceptsContextParam reports whether a function's parameter list contains a
// context.Context.
func acceptsContextParam(fn *ast.FuncDecl) bool {
	if fn.Type.Params == nil {
		return false
	}
	for _, param := range fn.Type.Params.List {
		sel, ok := param.Type.(*ast.SelectorExpr)
		if ok && sel.Sel.Name == "Context" {
			return true
		}
	}
	return false
}

// reportMissingContextParam emits the rule-3 finding for a function.
func reportMissingContextParam(pos token.Position, name string) {
	fmt.Fprintf(os.Stderr,
		"%s: saga violation: %s does not accept context.Context\n"+
			"  Saga handlers must accept context.Context to support timeout enforcement.\n"+
			"  See docs/SAGA_PATTERN.md §Saga Timeout.\n",
		pos, name)
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
		root := strings.TrimSuffix(strings.TrimSuffix(pattern, "/..."), "...")
		if err := filepath.Walk(root, collectDirs(&dirs, seen)); err != nil {
			return nil, err
		}
	}
	return dirs, nil
}

// collectDirs returns a walk func that appends unseen directories to dirs,
// skipping hidden and vendor directories (and everything below them).
func collectDirs(dirs *[]string, seen map[string]bool) filepath.WalkFunc {
	return func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if !info.IsDir() {
			return nil
		}
		if skipDir(info.Name()) {
			return filepath.SkipDir
		}
		if !seen[path] {
			seen[path] = true
			*dirs = append(*dirs, path)
		}
		return nil
	}
}

// skipDir reports whether the walker must not descend into a directory.
func skipDir(name string) bool {
	return strings.HasPrefix(name, ".") || name == "vendor"
}
