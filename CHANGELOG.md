# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.0.0] · 2021-11-04

The library is now compatible with TOML v1.0.0.

### Breaking changes
Decoding rejects certain inputs that were permitted before this version. It now correctly rejects [all invalid inputs from BurntSushi's test suite](https://github.com/BurntSushi/toml-test/tree/b13811e4d9723286b3e02981b1d1f8b67739f40b/tests/invalid).

- Throw `TomlDecodingException` when attempting injection into an already-defined table using dotted keys ([injection-1](https://gitlab.com/andrej88/toml-foolery/-/blob/v2.0.0/validator/toml-test/tests/invalid/table/injection-1.toml), [injection-2](https://gitlab.com/andrej88/toml-foolery/-/blob/v2.0.0/validator/toml-test/tests/invalid/table/injection-2.toml)).
- Throw `TomlDuplicateNameException` if giving an array-of-tables a name that was already used ([tables-1](https://gitlab.com/andrej88/toml-foolery/-/blob/v2.0.0/validator/toml-test/tests/invalid/array/tables-1.toml)).
- Throw `TomlDuplicateNameException` if giving a table a name that was already used for an array-of-tables ([tables-2](https://gitlab.com/andrej88/toml-foolery/-/blob/v2.0.0/validator/toml-test/tests/invalid/array/tables-2.toml)).
- Throw `TomlSyntaxException` when a comment contains the DEL character 0x7F ([comment-del](https://gitlab.com/andrej88/toml-foolery/-/blob/v2.0.0/validator/toml-test/tests/invalid/control/comment-del.toml)).
- Throw `TomlDecodingException` if attempting to access a non-table key as a table ([dotted-redefine-table](https://gitlab.com/andrej88/toml-foolery/-/blob/v2.0.0/validator/toml-test/tests/invalid/key/dotted-redefine-table.toml)).
- Throw `TomlDuplicateNameException` when an implicitly-declared table name is used for an array-of-tables ([array-implicit](https://gitlab.com/andrej88/[toml-foolery/-/blob/v2.0.0/validator/toml-test/tests/invalid/table/array-implicit.toml)).


### Non-breaking changes
- When attempting to decode invalid UTF escape sequences, a `TomlDecodingException` will be thrown containing the underlying `UTFException` as the `next` exception, instead of throwing the `UTFException` directly.
- Decoding certain UTF escape sequences no longer throws a `ConvOverflowException`, but rather a `TomlDecodingException` with an underlying `UTFException` if applicable.

### Documentation
- Fixed link to dpldocs in the readme.
- Add LICENSE file containing the text of the MIT license.
- Fix release date of 1.0.1 noted in the changelog.

---

## [1.0.1] · 2021-06-19

### Changed
- Improve error message when failing to write to a field during decoding.

### Fixed
- Fix compatibility with [pegged v0.4.5](https://github.com/PhilippeSigaud/Pegged/releases/tag/v0.4.5).
- Fix decoding in release builds ([GitHub #1](https://github.com/andrejp88/toml-foolery/issues/1)).

---

## [1.0.0] · 2020-04-21
- Initial release



[1.0.0]: https://gitlab.com/andrej88/toml-foolery/-/tree/v1.0.0
[1.0.1]: https://gitlab.com/andrej88/toml-foolery/-/tree/v1.0.1
[2.0.0]: https://gitlab.com/andrej88/toml-foolery/-/tree/v2.0.0
