# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Params::Filter is a Perl CPAN module providing secure field filtering for parameter construction. The module separates field filtering (checking which fields are present/absent) from value validation (checking if values are correct). It's security-focused, designed to exclude sensitive fields before they reach downstream systems.

## Development Commands

### Building and Testing

```bash
# Build the module
perl Makefile.PL
make

# Run all tests (59 tests across 6 files)
make test

# Run individual test files
prove -v t/00-load.t          # Module loading
prove -v t/01-functional.t     # Functional interface tests
prove -v t/02-oo-interface.t   # OO interface tests
prove -v t/03-modifier-methods.t  # Modifier methods
prove -v t/04-make_filter.t    # Closure interface tests
prove -vb t/benchmark.t        # Performance benchmarks

# Run single test from a file
perl -Ilib t/01-functional.t

# Clean build artifacts
make clean

# Install locally
make install
```

### Distribution

```bash
# Create CPAN distribution tarball
# IMPORTANT: Requires GNU tar (not BSD tar)
brew install gnu-tar  # macOS only

# Build distribution
make dist

# The tarball will be: Params-Filter-X.XXX.tar.gz
```

### Performance Testing

```bash
# User-facing benchmarks (in examples/)
perl examples/benchmark-interfaces.pl      # Compare functional vs OO vs closure
perl examples/benchmark-realistic.pl       # Realistic usage scenarios
perl examples/benchmark-vs-raw.pl          # Params::Filter vs raw Perl
perl examples/benchmark-expensive-validation.pl  # With downstream validation

# Development benchmarks (in dev-tools/)
perl dev-tools/benchmark-make_filter.pl    # Closure variants performance
perl dev-tools/benchmark-optimized-filter.pl  # Optimized filter() comparison
perl dev-tools/benchmark-three-variants.pl  # Three closure types
```

### Documentation

```bash
# View POD documentation
perldoc lib/Params/Filter.pm

# Check POD syntax
podchecker lib/Params/Filter.pm

# Generate HTML documentation
pod2html lib/Params/Filter.pm > docs.html
```

## Architecture

### Three Interfaces

The module provides three interfaces with different trade-offs:

1. **Closure Interface** (`make_filter`) - Maximum performance
   - Location: lib/Params/Filter.pm:223-267
   - Pre-compiled closures optimized for specific configurations
   - Three specialized variants based on accepted fields:
     - Required-only (empty accepted list)
     - Wildcard (accepted contains '*')
     - Accepted-specific (normal case)
   - Hashref input only, no error messages, immutable
   - Can be 20-25% faster than hand-written Perl

2. **Functional Interface** (`filter()`) - Flexible input parsing
   - Location: lib/Params/Filter.pm:790-928
   - Accepts hashrefs, arrayrefs, scalars
   - Returns detailed error messages
   - One-off filtering operations
   - Input parsing adds overhead vs closure interface

3. **Object-Oriented Interface** (`new_filter` + `apply`)
   - Location: lib/Params/Filter.pm:210-221, 701-709
   - Reusable filter objects
   - Modifier methods for dynamic reconfiguration
   - Most features but slowest performance

### Core Algorithm (5 Phases)

The `filter()` function processes data in 5 distinct phases:

1. **PHASE 1** (lines 797-831): Parse input data to hashref format
   - Handles hashrefs, arrayrefs (even/odd elements), scalars
   - Special '_' key for scalar input

2. **PHASE 2** (lines 846-853): Pre-compute optimization data structures
   - Build exclusion hash for O(1) lookups
   - Check for wildcard once (not per iteration)

3. **PHASE 3** (lines 856-877): Check required fields and copy to output
   - Fast-fail on missing required fields
   - Use hash slice for bulk copying
   - Early return for required-only filters

4. **PHASE 4** (lines 879-896): Apply accepted/excluded fields
   - Non-destructive operations
   - Two paths: wildcard vs accepted-specific
   - Exclusions always take precedence

5. **PHASE 5** (lines 919-927): Build return message
   - Combine parsing messages and debug warnings
   - Return filtered hashref and status message

### Key Design Principles

- **Security-first**: Excluded fields never reach downstream code
- **Non-destructive**: Original data never modified
- **Fail-closed**: Returns immediately on missing required fields
- **No value checking**: Only presence/absence of fields
- **Performance optimization**: Pre-computed exclusions, hash slices, specialized closures

### Module Structure

```
lib/Params/Filter.pm          # Main module (1522 lines)
├── make_filter()             # Closure interface (lines 223-267)
├── filter()                  # Functional interface (lines 790-928)
├── new_filter()              # Constructor (lines 210-221)
├── apply()                   # OO apply method (lines 701-709)
└── Modifier methods          # Dynamic config (lines 665-699)
    ├── set_required()
    ├── set_accepted()
    ├── set_excluded()
    ├── accept_all()
    └── accept_none()
```

## Important Implementation Notes

### Perl Version Requirements

- **Minimum**: Perl 5.36
- Uses modern features: signatures (`use v5.36`), postderef (`->@*`, `->%*`)
- No backward compatibility below 5.36

### Special Behaviors

1. **Wildcard '*'**: Only special in `accepted` parameter, not in `required` or `excluded`
2. **Empty accepted list []**: Means "accept none beyond required" (not "accept all")
3. **Odd array elements**: Last element becomes a flag with value 1
4. **Scalar input**: Stored with key '_' (must be in accepted list or use '*')
5. **Method chaining**: All modifier methods return `$self`

### Security Considerations

- **Exclusions always win**: Even if field is in required/accepted, exclusions take precedence
- **No regex matching**: Field names must match exactly (prevents bypass attacks)
- **No coderefs/callbacks**: Prevents code injection
- **No field name substitution**: Prevents confusion attacks

### Performance Trade-offs

- **Closure interface**: Fastest, but hashref-only, no error messages, immutable
- **Functional interface**: Flexible input parsing adds ~40% overhead
- **OO interface**: Reusable objects, but method dispatch overhead
- **Debug mode**: Adds overhead for unrecognized/excluded field reporting

## Testing Strategy

The test suite (59 tests across 6 files) covers:

1. **t/00-load.t**: Module loading and version checks
2. **t/01-functional.t**: filter() function with various input formats
3. **t/02-oo-interface.t**: new_filter() and apply() methods
4. **t/03-modifier-methods.t**: set_required(), set_accepted(), etc. (23 tests)
5. **t/04-make_filter.t**: make_filter() closure interface (10 subtests)
6. **t/benchmark.t**: Performance benchmarks (optional, requires Benchmark.pm)

Test framework: Test2::V0 (modern Test2-based testing)

## Common Development Patterns

### Adding New Features

1. Decide which interface(s) the feature applies to
2. Add implementation to lib/Params/Filter.pm
3. Add tests to appropriate t/*.t file
4. Update POD documentation in module file
5. Add example to examples/ directory (if user-facing)
6. Update Changes file with clear description
7. Run full test suite: `make test`

### Performance Optimization

When optimizing performance:
- Profile with dev-tools/profile.pl
- Compare against closure interface baseline
- Benchmark with dev-tools/benchmark-*.pl scripts
- Ensure optimizations apply to all three interfaces where applicable
- Document performance characteristics in POD

### Distribution Releases

1. Update version in lib/Params/Filter.pm (`our $VERSION = 'X.XXX';`)
2. Update Changes file with version, date, and changes
3. Ensure all tests pass: `make test`
4. Check POD syntax: `podchecker lib/Params/Filter.pm`
5. Build distribution: `make dist` (requires gtar on macOS)
6. Test tarball locally before CPAN upload
7. Upload to PAUSE/CPAN

## Examples Directory

The examples/ directory contains 11 teaching examples plus 4 benchmark scripts:

- **Teaching examples**: basic_usage.pl, oo_interface.pl, closure_interface.pl, wildcard.pl, error_handling.pl, debug_mode.pl, modifier_methods.pl, advanced_filtering.pl, arrayref_input.pl, edge_cases.pl, strict_construction.pl
- **Performance examples**: benchmark-interfaces.pl, benchmark-realistic.pl, benchmark-vs-raw.pl, benchmark-expensive-validation.pl

All examples are executable and use `use v5.36;` for consistency.

## Dependencies

- **Runtime**: Only Exporter (core Perl module)
- **Testing**: Test2::V0
- **Build**: ExtUtils::MakeMaker
- **Distribution**: GNU tar (gtar) for macOS to avoid PAX headers

## Common Issues

### PAX Headers Problem

macOS BSD tar creates PAX headers that CPAN rejects. Solution:
```bash
brew install gnu-tar
# Makefile.PL already configured to use gtar
```

### Test Failures

If tests fail:
1. Check Perl version: `perl -v` (must be 5.36+)
2. Verify Test2::V0 installed: `cpan Test2::V0`
3. Check for syntax errors: `perl -c lib/Params/Filter.pm`
4. Run single test for debugging: `perl -Ilib t/XX-name.t`
