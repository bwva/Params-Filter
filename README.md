# Params::Filter

Fast field filtering for parameter construction.

## Description

`Params::Filter` provides fast, lightweight parameter filtering that checks only for the presence or absence of specified fields. It does NOT validate values - no type checking, truthiness testing, or lookups.

This module separates field filtering from value validation:

- **Field filtering** (this module) - Check which fields are present/absent
- **Value validation** (later step) - Check if field values are correct

This approach handles common parameter issues:
- Subroutine signatures can become unwieldy with many parameters
- Ad-hoc argument checking is error-prone
- Validation may not catch missing inputs quickly enough
- The number of fields to check multiplies validation time

### When to Use This Module

This module is useful when you have:

- Pre-defined filter rules (from config files, constants, database schemas)
- Known downstream input or process parameters (for APIs, method/subroutine arguments, database operations)
- Incoming data from differing sources (web forms, APIs, databases, user input)
- No guarantee that incoming data is consistent or complete
- Need to process multiple datasets with the same rules
- Want to reject unwanted fields before value validation

### When NOT to Use This Module

If you're constructing both the filter rules AND the data structure 
at the same point in your code, you probably don't need this module. 
The module's expected use is to apply pre-defined rules to data that 
may be inconsistent or incomplete for its intended use. 
If there isn't repetition or an unknown/unreliable data structure, this might be overkill.

### This Module Does NOT Do Fancy Stuff

As much as this module attempts to be versatile in usage, there are some VERY HANDY AFFORDANCES IT DOES NOT PROVIDE:

- No regex field name matching for designating fields to require, accept, or exclude
- No conditional field designations within a filter: 

    `if 'mailing_address' require 'postal_code'`   # No way provided to do this

    But see `set_required()`, `set_accepted()`, `set_excluded()`, 
    as ways to adjust a filter's behavior - or just deploy alternative filters.
- No coderefs or callbacks for use when filtering
- No substitutions or changes to field names 

    But if the downstream can handle it, filtering could try variations:

    `$filter->set_accepted(qw/fname firstname first_name/);` 
- No built-in filter lists except null `[]` = none
- No fields ADDED to yielded data, EXCEPT:

    * If the provided data resolves to a list or array with an odd number of elements, 
    the LAST element is treated as a flag, set to the value 1

    * If the provided data resolves to a single non-reference scalar (probably a text string) 
    the data is returned as a hashref value with the key `‘_’`, and returned if `'_'` is
    included in the accepted list or the list is set to `['*']` (accept all)

## Installation

```bash
perl Makefile.PL
make
make test
make install
```

## Usage

### Functional Interface

```perl
use Params::Filter;    # auto-imports filter() subroutine

# Define filter rules
my @required_fields = qw(name email);
my @accepted_fields = qw(phone city state zip);
my @excluded_fields = qw(ssn password);

# Apply filter to incoming data (from web form, CLI, API, etc.)
my ($filtered_data, $status) = filter(
    $incoming_params,    # Data from external source
    \@required_fields,
    \@accepted_fields,
    \@excluded_fields,
);

if ($filtered_data) {
    # Success - use filtered data
    process_user($filtered_data);
} else {
    # Error - missing required fields
    die "Validation failed: $status";
}
```

### Object-Oriented Interface

```perl
use Params::Filter;

my $user_filter = Params::Filter->new_filter({
    required => ['username', 'email'],
    accepted => ['first_name', 'last_name', 'phone', 'bio'],
    excluded => ['password', 'ssn', 'credit_card'],
});

# Apply same filter to multiple incoming datasets
my ($user1, $msg1) = $user_filter->apply($web_form_data);
my ($user2, $msg2) = $user_filter->apply($api_request_data);
my ($user3, $msg3) = $user_filter->apply($db_record_data);
```

### Modifier Methods for Dynamic Configuration

The OO interface provides methods to modify a filter's configuration after creation. 

```perl
# Start with an empty filter (rejects all by default)
my $filter = Params::Filter->new_filter();

# Configure it in steps as needed
$filter->set_required(['id', 'name']);
# later:
$filter->set_accepted(['email', 'phone'])
$filter->set_excluded(['password']);

# Or use method chaining for one-liner setup
my $filter = Params::Filter->new_filter()
    ->set_required(['user_id'])
    ->accept_all()  # Convenience method for wildcard
    ->set_excluded(['api_key']);
```

#### Available Modifier Methods

- **`set_required(\@fields | @fields)`** - Set required fields (accepts arrayref or list)
- **`set_accepted(\@fields | @fields)`** - Set accepted fields (accepts arrayref or list)
- **`set_excluded(\@fields | @fields)`** - Set excluded fields (accepts arrayref or list)
- **`accept_all()`** - Convenience method: sets accepted to `['*']` (wildcard mode)
- **`accept_none()`** - Convenience method: sets accepted to `[]` (reject all extras)

#### Important Behavior Notes

**Empty Calls Set to Empty Arrays:**
If no fields are provided to `set_required()`, `set_accepted()`, or `set_excluded()`, the respective list is set to an empty array `[]`:

```perl
$filter->set_accepted();  # Sets accepted to `[]`
# Result: Only required fields will be accepted (extras rejected)
```

**Method Chaining:**
All modifier methods return `$self` for chaining:
```perl
$filter->set_required(['id'])
        ->set_accepted(['name'])
        ->accept_all();  # Overrides set_accepted
```

**Mutability:**
A filter may call its modifier methods more than once, and the changes take effect immediately.

**Meta-Programming Use Cases:**
These methods enable dynamic configuration for conditional scenarios:

```perl
# Environment-based configuration
my $filter = Params::Filter->new_filter();

if ($ENV{MODE} eq 'production') {
    $filter->set_required(['api_key', 'endpoint'])
              ->set_accepted(['timeout', 'retries'])
              ->set_excluded(['debug_info']);
}
else {
    $filter->set_required(['debug_mode'])
              ->accept_all();
}

# Dynamic field lists from config
my $config_fields = load_config('fields.json');
$filter->set_required($config_fields->{required})
          ->set_accepted($config_fields->{accepted})
          ->set_excluded($config_fields->{excluded});
```

## Features

- **Dual interface**: Functional or OO usage
- **Fast-fail**: Returns immediately on missing required parameters
- **Fast-success**: Returns immediately if all required parameters are provided and no others are provided or will be accepted
- **Flexible input**: Accepts hashrefs, arrayrefs, or scalars
- **Wildcard support**: Use `'*'` in accepted list to accept all fields
- **No value checking**: Only presence/absence of fields
- **Debug mode**: Optional warnings about unrecognized or excluded fields
- **Method chaining**: Modifier methods return `$self`
- **Perl 5.36+**: Modern Perl with signatures and post-deref
- **No dependencies**: Only core Perl's Exporter

## Parameters

### `filter($args, $required, $accepted, $excluded, $debug)`

- **$args**: Input parameters (hashref, arrayref, or scalar)
- **$required**: Arrayref of field names that must be present
- **$accepted**: Arrayref of optional field names to accept (default: `[]`)
- **$excluded**: Arrayref of field names to remove even if accepted (default: `[]`)
- **$debug**: Boolean to enable warnings (default: 0)

### Returns

In scalar context: hashref with filtered parameters, or undef on failure 

In list context: (hashref with filtered parameters, status_message) or (undef, error_message) 

## Wildcard Feature

The `accepted` parameter supports a wildcard `'*'` to accept all fields (except those in `excluded`).

### Wildcard Usage

```perl
# Accept all fields
filter($input, [], ['*']);

# Accept all fields except specific exclusions
filter($input, [], ['*'], ['password', 'ssn']);

# Required + all other fields
filter($input, ['id', 'name'], ['*']);

# Wildcard can appear anywhere in accepted list
filter($input, [], ['name', 'email', '*']);  # debugging: add '*' to see everything
filter($input, [], ['*', 'phone', 'address']);
```

### Important Notes

- `'*'` is **only special in the `accepted` parameter**
- In `required` or `excluded`, `'*'` is treated as a literal field name
- Empty `[]` for accepted means "accept none beyond required" (backward compatible)
- Multiple wildcards are redundant but harmless
- Exclusions are always removed before acceptance is processed

### Debugging Pattern

A common debugging pattern is to add `'*'` to an existing accepted list:

```perl
# Normal operation
filter($input, ['id'], ['name', 'email']);

# Debugging - see all inputs
filter($input, ['id'], ['name', 'email', '*']);
```

## Examples

### Basic Form Validation

```perl
use Params::Filter;

# Define filtering rules (could be from config file)
my @required = qw(name email);
my @accepted = qw(phone city state zip);

# Apply to incoming web form data
my ($user_data, $status) = filter(
    $form_submission,   # Data from web form
    \@required,
    \@accepted,
);

if ($user_data) {
    register_user($user_data);
} else {
    show_error($status);
}
```

### Reusable Filter for Multiple Data Sources

```perl
# Create filter once
my $user_filter = Params::Filter->new_filter({
    required => ['username', 'email'],
    accepted => ['full_name', 'phone', 'bio'],
    excluded => ['password', 'ssn', 'credit_card'],
});

# Apply to multiple incoming datasets
my ($user1, $msg1) = $user_filter->apply($web_form_data);
my ($user2, $msg2) = $user_filter->apply($api_request_data);
my ($user3, $msg3) = $user_filter->apply($csv_import_data);
```

### Environment-Specific Filtering

```perl
my $filter = Params::Filter->new_filter();

if ($ENV{APP_MODE} eq 'production') {
    # Strict: only specific fields allowed
    $filter->set_required(['api_key'])
          ->set_accepted(['timeout', 'retries'])
          ->set_excluded(['debug_info', 'verbose']);
} else {
    # Development: allow everything
    $filter->set_required(['debug_mode'])
          ->accept_all();
}

my ($config, $msg) = $filter->apply($incoming_config);
```

### Security Filtering

```perl
# Remove sensitive fields from user input
my ($safe_data, $msg) = filter(
    $user_input,
    ['username', 'email'],           # required
    ['full_name', 'phone', 'bio'],    # accepted
    ['password', 'ssn', 'api_key'],   # excluded
);

# Result contains only safe fields
# password, ssn, api_key are removed even if provided
```

### Dynamic Configuration from File

```perl
# Load filter rules from config file
my $config = decode_json(`cat filters.json`);

my $filter = Params::Filter->new_filter()
    ->set_required($config->{user_create}{required})
    ->set_accepted($config->{user_create}{accepted})
    ->set_excluded($config->{user_create}{excluded});

# Apply to incoming data
my ($filtered, $msg) = $filter->apply($api_data);
```

### Data Segregation for Multiple Subsystems

A common pattern is splitting incoming data into subsets for different handlers or storage locations. Each filter extracts only the fields needed for its specific purpose, implementing security through compartmentalization.

```perl
# Three different forms collect overlapping data:

# Main subscription form collects: 
#  name, email, zip, 
#  user_id, password, credit_card_number, subscription_term

# Subscriber profile form collects: 
#  name, email, address, city, state, zip, 
#  user_id, password, credit_card_number, 
#  phone, occupation, position, education 
#  alt_card_number, billing_address, billing_zip

# Promo subscription form collects: 
#  name, email, zip, subscription_term, 
#  user_id, password, credit_card_number, promo_code

my $data = $webform->input(); # From any of the above

# Personal data filter - general user info (no sensitive data)
my $person_filter = Params::Filter->new_filter({
    required => ['name', 'user_id', 'email'],
    accepted => ['address', 'city', 'state', 'zip', 'phone', 
                 'occupation', 'position', 'education'],
    excluded => ['password', 'credit_card_number'],
});

# Business data filter - subscription and billing info
my $biz_filter = Params::Filter->new_filter({
    required => ['user_id', 'subscription_term', 'credit_card_number', 'zip'],
    accepted => ['alt_card_number', 'billing_address', 'billing_zip', 'promo_code'],
    excluded => ['password'],
});

# Authentication data filter - only credentials
my $auth_filter = Params::Filter->new_filter({
    required => ['user_id', 'password'],
    accepted => [],
    excluded => [],
});

# Apply all filters to the same web form submission
my ($person_data, $pmsg) = $person_filter->apply($data);
my ($biz_data,    $bmsg) = $biz_filter->apply($data);
my ($auth_data,   $amsg) = $auth_filter->apply($data);

unless ($person_data && $biz_data && $auth_data) {
    return "Unable to add user: " .
        join ' ' => grep { $_ ne 'Admitted' } ($pmsg, $bmsg, $amsg);
}

# Collect any debug warnings from successful filters 
# if the filter's `debug` parameter is 'true' (1)
my @warnings = grep { $_ ne 'Admitted' } ($pmsg, $bmsg, $amsg);
warn "Params filter debug warnings:\n" . join("\n", @warnings) . "\n"
    if @warnings;

# Route each subset to appropriate handler
$self->add_user($person_data);           # User profile
$self->set_subscription($biz_data);       # Billing system
$self->set_password($auth_data);          # Auth system
```

NOTE: The original `$data` is not modified by any filter. Each call to `apply()` creates its own internal copy, so the same data can be safely processed by multiple filters.

### More Examples

See the `examples/` directory for complete working scripts:
- `basic_usage.pl` - Simple form input filtering
- `oo_interface.pl` - Reusable filters
- `wildcard.pl` - Wildcard acceptance patterns
- `error_handling.pl` - Various error handling strategies
- `debug_mode.pl` - Development-time warnings
- `edge_cases.pl` - Unusual input formats
- `arrayref_input.pl` - Arrayref vs hashref inputs
- `advanced_filtering.pl` - Complex filtering patterns
- `modifier_methods.pl` - Dynamic configuration with modifier methods

## Author

Bruce Van Allen <bva@cruzio.com>

## License

perl_5

## Copyright

Copyright (C) 2026, Bruce Van Allen
