# AC-042-04: Password hashing guidance in `docs/SECURITY.md`

## AC-042-04-01 — Only a password-hashing algorithm is used
Given `docs/SECURITY.md`
When the password hashing section is read
Then the file contains the heading `## Password Hashing`
And the section contains `Argon2id`
And it contains `bcrypt`
And it states that Argon2id is preferred and bcrypt is the accepted alternative
And it states that a password is never stored in plaintext or reversibly encrypted

## AC-042-04-02 — Fast general-purpose hashes are forbidden
Given the password hashing section of `docs/SECURITY.md`
When the algorithm prohibition is read
Then the section contains `MD5`, `SHA-1`, and `SHA-256`
And it states that none of them is acceptable for password storage

## AC-042-04-03 — Work factors are recorded as minimums
Given the password hashing section of `docs/SECURITY.md`
When the parameter rule is read
Then the section contains `cost` and `12` as the bcrypt minimum work factor
And it contains `19 MiB` as the Argon2id minimum memory
And it contains `iterations` and `parallelism` as required Argon2id parameters

## AC-042-04-04 — Verification is constant-time and hashes are upgraded
Given the password hashing section of `docs/SECURITY.md`
When the verification rule is read
Then the section contains `constant-time`
And it forbids comparing hashes with `==`
And it contains `rehash`
And it states that a weaker stored hash is rehashed on the next successful login without invalidating the session
