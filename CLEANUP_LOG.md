# Heifer Project Cleanup Log

Date: 2026-01-03

## Summary

Removed unnecessary documentation files, obsolete planning documents, temporary scripts, and error logs to streamline the repository structure.

## Files Deleted

### Root Directory
1. **PLAN_FIX_GLOBAL_VARIABLES.md**
   - Obsolete planning document for fixing TypeScript global variable translation
   - This was a temporary working document that is no longer needed
   - The issues discussed have been resolved or superseded

2. **README-bk.md**
   - Backup copy of README file
   - Redundant - main README.md is sufficient

### Documentation Directory (docs/)
3. **note.txt**
   - Personal scratch notes containing random code snippets
   - Included unorganized notes about protocol verification, timing automata, etc.
   - Not relevant to project documentation

4. **docker_cmd.txt**
   - Temporary docker commands for development
   - Basic commands like `docker ps`, `docker exec`, etc.
   - Can be referenced from official Docker documentation

5. **old-readme.md**
   - Outdated README file
   - Content superseded by current README.md

### TypeScript-to-Heifer Module (ts_to_heifer/)

#### Deleted: ts_to_heifer/README_COMMANDS.md
- **Reason**: Redundant command reference
- **Content**: Detailed command-line reference for parse/translate/verify pipeline
- **Why deleted**: Information is better placed in the main project README or inline comments

#### Deleted: Test Scripts (ts_to_heifer/test/)
6. **parse_all_tests.sh**
7. **translate_all_tests.sh**
8. **verify_simple_increment.sh**
9. **test_spec_translation.sh**
   - Ad-hoc test scripts that are not part of the formal test suite
   - Can be recreated if needed using the main scripts (translate.sh, verify.sh)
   - Better to use the formal test suite instead

#### Deleted: Error Output Files (ts_to_heifer/test/heifer_output/)
10. **03_control_flow_error.txt**
11. **04_operators_error.txt**
12. **06_objects_error.txt**
13. **07_arrays_error.txt**
14. **08_loops_error.txt**
15. **10_complex_functions_error.txt**
    - Temporary error logs from failed translation attempts
    - Not useful as reference - errors should be fixed, not archived
    - Clutters the repository

### Test Evaluation Directory
16. **test/evaluation/small_examples/temp.txt**
    - Temporary file with no meaningful content

## Files Preserved

### Important Documentation (kept)
- **README.md** - Main project documentation
- **TODO.md** - Project roadmap and tasks
- **docs/development.md** - Development guidelines
- **docs/docker.md** - Docker setup instructions
- **docs/web.md** - Web build documentation
- **docs/why3.md** - Why3 integration documentation
- **docs/FM2024_TR.pdf** - Technical reports
- **docs/ICFP2024_TR.pdf**

### Important Scripts (kept)
- **ts_to_heifer/translate.sh** - Main translation pipeline
- **ts_to_heifer/verify.sh** - Full verification pipeline
- **test/utility.sh** - Test utilities
- **web/examples.sh** - Web examples generator
- **benchmarks/ho/generate.sh** - Benchmark generation
- **benchmarks/ho/prusti-wip/run.sh** - Prusti test runner
- **benchmarks/ho/prusti-wip/run-test.sh**

### Important Test Outputs (kept)
- **ts_to_heifer/test/heifer_output/*.ml** - Successful translation outputs
- **ts_to_heifer/test/README.md** - Test documentation

## Repository Structure After Cleanup

```
Heifer-type/
├── README.md                    # Main documentation
├── TODO.md                      # Project tasks
├── docs/
│   ├── development.md          # Dev guidelines
│   ├── docker.md               # Docker setup
│   ├── web.md                  # Web build
│   ├── why3.md                 # Why3 integration
│   ├── FM2024_TR.pdf           # Technical reports
│   └── ICFP2024_TR.pdf
├── ts_to_heifer/
│   ├── translate.sh            # Translation pipeline
│   ├── verify.sh               # Verification pipeline
│   └── test/
│       ├── README.md           # Test documentation
│       └── heifer_output/      # Successful outputs only
└── CLEANUP_LOG.md              # This file
```

## Impact

- **Repository size**: Reduced by removing redundant and obsolete files
- **Clarity**: Easier to navigate without temporary/obsolete documentation
- **Maintainability**: Less confusion about which documentation is current
- **No functionality lost**: All deleted files were either duplicates, obsolete, or easily recreatable

## Recommendations

1. **Future temporary files**: Use a `.gitignore`d `scratch/` or `tmp/` directory
2. **Planning documents**: Keep in issue tracker or project management tool, not in repo
3. **Error logs**: Log to gitignored directories, only commit when useful as test fixtures
4. **Command references**: Maintain in main README or as inline script comments

## Related Work

This cleanup was performed as part of the TypeScript-to-Heifer translation project. Prior analysis work included:
- Analyzing Heifer's record type support
- Identifying missing core language constructs for records
- Creating implementation plan for full record support

See commit history for details on the record type analysis.
