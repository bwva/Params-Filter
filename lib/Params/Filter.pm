package Params::Filter;
use v5.36;
our $VERSION = '0.006_002';

=head1 NAME

Params::Filter - Fast field filtering for parameter construction

=head1 SYNOPSIS

    use Params::Filter;

    # Define filter rules
    my @required_fields = qw(name email);
    my @accepted_fields = qw(phone city state zip);
    my @excluded_fields = qw(ssn password);

    # Functional interface
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

    # Object-oriented interface
    my $user_filter = Params::Filter->new_filter({
        required => ['username', 'email'],
        accepted => ['first_name', 'last_name', 'phone', 'bio'],
        excluded => ['password', 'ssn', 'credit_card'],
    });

    # Apply same filter to multiple incoming datasets
    my ($user1, $msg1) = $user_filter->apply($web_form_data);
    my ($user2, $msg2) = $user_filter->apply($api_request_data);
    my ($user3, $msg3) = $user_filter->apply($db_record_data);

=head1 DESCRIPTION

C<Params::Filter> provides fast, lightweight parameter filtering that
checks only for the presence or absence of specified fields. It does B<not>
validate values - no type checking, truthiness testing, or lookups.

This module separates field filtering from value validation:

=over 4

=item * **Field filtering** (this module) - Check which fields are present/absent

=item * **Value validation** (later step) - Check if field values are correct

=back

This approach handles common parameter issues:

=over 4

=item * Subroutine signatures can become unwieldy with many parameters

=item * Ad-hoc argument checking is error-prone

=item * Validation may not catch missing inputs quickly enough

=item * The number of fields to check multiplies validation time

=back

=head2 When to Use This Module

This module is useful when you have:

=over 4

=item * Pre-defined filter rules (from config files, constants, database schemas)

=item * Known downstream input or process parameters (for APIs, method/subroutine arguments, database operations)

=item * Incoming data from differing sources (web forms, APIs, databases, user input)

=item * No guarantee that incoming data is consistent or complete

=item * Need to process multiple datasets with the same rules

=item * Want to reject unwanted fields before value validation

=back

=head2 When NOT to Use This Module

If you're constructing both the filter rules B<and> the data structure at the
same point in your code, you probably don't need this module except 
during development or debugging. The module's expected use is 
to apply pre-defined rules to data that may be inconsistent or 
incomplete for its intended use. If there isn't repetition 
or an unreliable data structure, this might be overkill.

=cut

=head2 This Module Does NOT Do Fancy Stuff

As much as this module attempts to be versatile in usage, there are some 
B<very handy affordances it does NOT provide:>

=over 4

=item * No regex field name matching for designating fields to require, accept, or exclude

=item * No conditional field designations within a filter:
    C<if 'mailing_address' require 'postal_code'>.
But see C<set_required()>, C<set_accepted()>, C<set_excluded()>, 
as ways to adjust a filter's behavior - or just have alternative filters.

=item * No coderefs or callbacks for use when filtering

=item * No substitutions or changes to field names

=item * No built-in filter lists except null [] = none

=item * No fields B<added> to data

=back

=cut

use Exporter;
our @ISA		= qw{ Exporter  };
our @EXPORT		= qw{ filter };

sub new_filter {
	my ($class,$args) = @_;
	$args = {} unless ($args and ref($args) =~ /hash/i);
	my $self			= {
		required	=> $args->{required} || [],
		accepted	=> $args->{accepted} || [],
		excluded	=> $args->{excluded} || [],
		debug		=> $args->{DEBUG} || $args->{debug} || 0,
	};
	bless $self, __PACKAGE__;
	return $self;
}

=head1 OBJECT-ORIENTED INTERFACE

=head2 new_filter

    my $filter = Params::Filter->new_filter({
        required => ['field1', 'field2'],
        accepted => ['field3', 'field4', 'field5'],
        excluded => ['forbidden_field'],
        DEBUG    => 1,              # Optional debug mode
    });

    # Empty constructor - rejects all fields by default
    my $strict_filter = Params::Filter->new_filter();

Creates a reusable filter object with predefined field rules. The filter
can then be applied to multiple datasets using the L</apply> method.

=head3 Parameters

=over 4

=item * C<required> - Arrayref of names of required fields (default: [])

=item * C<accepted> - Arrayref of names of optional fields (default: [])

=item * C<excluded> - Arrayref of names of fields to always remove (default: [])

=item * C<DEBUG> - Boolean to enable debug warnings (default: 0)

=back

=head3 Returns

A C<Params::Filter> object

=head3 Example

    # Create filter for user registration data
    my $user_filter = Params::Filter->new_filter({
        required => ['username', 'email'],
        accepted => ['first_name', 'last_name', 'phone', 'bio'],
        excluded => ['password', 'ssn', 'credit_card'],
    });

    # Apply to multiple incoming datasets
    my ($user1, $msg1) = $user_filter->apply($web_form_data);
    my ($user2, $msg2) = $user_filter->apply($api_request_data);

=head2 apply

    my ($filtered, $status) = $filter->apply($input_data);

Applies the filter's predefined rules to input data. This is the OO
equivalent of the L</filter> function.

=head3 Parameters

=over 4

=item * C<$input_data> - Hashref, arrayref, or scalar to filter

=back

=head3 Returns

In list context: C<(hashref, status_message)> or C<(undef, error_message)>

In scalar context: Hashref with filtered parameters, or C<undef> on failure

=head3 Example

    my $filter = Params::Filter->new_filter({
        required => ['id', 'type'],
        accepted => ['name', 'value'],
    });

    # Process multiple records from database
    for my $record (@db_records) {
        my ($filtered, $msg) = $filter->apply($record);
        if ($filtered) {
            process_record($filtered);
        } else {
            log_error("Record failed: $msg");
        }
    }

=cut

sub set_required {
	my ($self, @fields)	= @_;
	@fields 			= ref $fields[0] eq 'ARRAY' ? $fields[0]->@* : @fields;
	my @required		= grep { defined } @fields;
	$self->{required}	= @required ? [ @required ] : [];
	return $self;
}

sub set_accepted {
	my ($self, @fields)	= @_;
	@fields 			= ref $fields[0] eq 'ARRAY' ? $fields[0]->@* : @fields;
	my @accepted		= grep { defined } @fields;
	$self->{accepted}	= @accepted ? [ @accepted ] : [];
	return $self;
}

sub accept_all {
	my ($self)			= @_;
	$self->{accepted}	= ['*'];
	return $self;
}

sub accept_none {
	my ($self)			= @_;
	$self->{accepted}	= [];
	return $self;
}

sub set_excluded {
	my ($self, @fields)	= @_;
	@fields				= ref $fields[0] eq 'ARRAY' ? $fields[0]->@* : @fields;
	my @excluded		= grep { defined } @fields;
	$self->{excluded}	= @excluded ? [ @excluded ] : [];
	return $self;
}

sub apply {
	my ($self,$args) = @_;
	my $req		= $self->{required} || [];
	my $ok		= $self->{accepted} || [];
	my $no		= $self->{excluded} || [];
	my $db		= $self->{debug} || 0;
	my @result	= filter( $args, $req, $ok, $no, $db);
	return wantarray ? @result : $result[0];
}

=head1 MODIFIER METHODS

Modifier methods allow dynamic configuration of filter rules after creation of the filter object.
All methods return C<$self> for method chaining. 
A filter may call its modifier methods more than once, and the changes take effect immediately.

=head2 set_required

    $filter->set_required(['id', 'name', 'email']);  # Arrayref
    $filter->set_required('id', 'name', 'email');    # List
    $filter->set_required();                         # Clears to []

Sets the required field names. Accepts either an arrayref or a list of
field names. Calling with no arguments sets required to empty array.

=head2 set_accepted

    $filter->set_accepted(['phone', 'city']);  # Arrayref
    $filter->set_accepted('phone', 'city');    # List
    $filter->set_accepted();                   # Clears to []
    $filter->set_accepted(['*']);              # Accept all (except excluded)

Sets the optional (accepted) field names. Accepts either an arrayref or a
list of field names. Calling with no arguments sets accepted to empty array.

=head2 set_excluded

    $filter->set_excluded(['password', 'ssn']);  # Arrayref
    $filter->set_excluded('password', 'ssn');    # List
    $filter->set_excluded();                     # Clears to []

Sets the excluded field names (fields to always remove). Accepts either an
arrayref or a list of field names. Calling with no arguments sets excluded
to empty array.

=head2 accept_all

    $filter->accept_all();  # Sets accepted to ['*']

Convenience method that sets accepted fields to C<['*']> (wildcard mode),
allowing all fields except those in excluded.

=head2 accept_none

    $filter->accept_none();  # Sets accepted to []

Convenience method that sets accepted fields to C<[]> (empty array),
allowing only required fields.

=head3 Modifier Method Examples

    # Method chaining for one-liner configuration
    my $filter = Params::Filter->new_filter();
    # When needed:
    $filter->set_required(['id', 'name'])
        ->set_accepted(['email', 'phone'])
        ->set_excluded(['password']);

    # Environment-based configuration
    my $filter = Params::Filter->new_filter();

    if ($ENV{MODE} eq 'production') {
        $filter->set_required(['api_key'])
              ->set_accepted(['timeout', 'retries'])
              ->set_excluded(['debug_info']);
    } else {
        $filter->set_required(['debug_mode'])
              ->accept_all();
    }

    # Dynamic configuration from config file
    if ( $DEBUG ) {
        my $db_config = load_config('debug_fields.json');
        $filter->set_required($db_config->{required})
          ->set_accepted($db_config->{accepted})
          ->set_excluded($db_config->{excluded});
    }

=head1 FUNCTIONAL INTERFACE

=head2 filter

    my ($filtered, $status) = filter(
        $input_data,     # Hashref, arrayref, or scalar
        \@required,      # Arrayref of required field names
        \@accepted,      # Arrayref of optional field names (default: [])
        \@excluded,      # Arrayref of names of fields to remove (default: [])
        $debug_mode,     # Boolean: enable warnings (default: 0)
    );

    # Scalar context - returns filtered hashref or undef on failure
    my $result = filter($input, \@required, \@accepted);

Filters input data according to field specifications. Only checks for
presence/absence of fields, not field values.

=head3 Parameters

=over 4

=item * C<$input_data> - Input parameters (hashref, arrayref, or scalar)

=item * C<\@required> - Arrayref of names of fields that B<must> be present

=item * C<\@accepted> - Arrayref of optional names of fields to accept (default: [])

=item * C<\@excluded> - Arrayref of names of fields to remove even if accepted (default: [])

=item * C<$debug_mode> - Boolean to enable warnings (default: 0)

=back

=head3 Returns

In list context: C<(hashref, status_message)> or C<(undef, error_message)>

In scalar context: Hashref with filtered parameters, or C<undef> on failure

=head3 Example

    # Define filter rules (could be from config file)
    my @required = qw(username email);
    my @accepted = qw(full_name phone);
    my @excluded = qw(password ssn);

    # Apply to incoming data from web form
    my ($user_data, $msg) = filter(
        $form_submission,
        \@required,
        \@accepted,
        \@excluded,
    );

    if ($user_data) {
        create_user($user_data);
    } else {
        log_error($msg);
    }

=cut

sub filter ($args,$req,$ok=[],$no=[],$db=0) {
	my %args		= ();
	my @messages	= ();	# Parsing messages (always reported)
	my @warnings	= ();	# Debug warnings (only when $db is true)

	if (ref $args eq 'HASH') {
		%args	= $args->%*
	}
	elsif (ref $args eq 'ARRAY') {
		if (ref($args->[0]) eq 'HASH') {
			%args	= $args->[0]->%*;			# Ignore the rest
		}
		else {
			my @args	= $args->@*;
			if (@args == 1) {
				%args = ( '_' => $args[0] );	# make it a value with key '_'
				my $preview = length($args[0]) > 20
					? substr($args[0], 0, 20) . '...'
					: $args[0];
				push @messages => "Plain text argument accepted with key '_': '$preview'";
			}
			elsif ( @args % 2 ) {
				%args = (@args, 1);				# make last arg element a flag
				push @messages => "Odd number of arguments provided; " .
					"last element '$args[-1]' converted to flag with value 1";
			}
			else {
				%args = @args;					# turn array into hash pairs
			}
		}
	}
	elsif ( !ref $args ) {
		%args	= ( '_' => $args);				# make it a value with key '_'
		my $preview = length($args) > 20
			? substr($args, 0, 20) . '...'
			: $args;
		push @messages => "Plain text argument accepted with key '_': '$preview'";
	}

	my @required_flds	= $req->@*;
	unless ( keys %args ) {
		my $err = "Unable to initialize without required arguments: " .
			join ', ' => map { "'$_'" } @required_flds;
		return wantarray ? (undef, $err) : undef;
	}

	if ( scalar keys(%args) < @required_flds ) {
		my $err	= "Unable to initialize without all required arguments: " .
			join ', ' => map { "'$_'" } @required_flds;
		return wantarray ? (undef, $err) : undef;
	}

	# Now create the output hashref
	my $filtered	= {};

	# Check for each required field
	my @missing_required;
	my $used_keys	= 0;
	for my $fld (@required_flds) {
		if ( exists $args{$fld} ) {
			$filtered->{$fld} = delete $args{$fld};
			$used_keys++;
		}
		else {
			push @missing_required => $fld;
		}
	}
	# Return fast if all set
	# required fields assured and no other fields provided
	if ( keys(%args) == 0 ) {
		return wantarray ? ($filtered, "Admitted") : $filtered;
	}
	# required fields assured and no more fields allowed
	if ( scalar keys $filtered->%* == @required_flds and not $ok->@*) {
		return wantarray ? ($filtered, "Admitted") : $filtered;
	}
	# Can't continue
	if ( @missing_required ) {
		my $err = "Unable to initialize without required arguments: " .
			join ', ' => map { "'$_'" } @missing_required;
		return wantarray ? (undef, $err) : undef;
	}

	# Now remove any excluded fields
	my @excluded;
	for my $fld ($no->@*) {
		if ( exists $args{$fld} ) {
			delete $args{$fld};
			push @excluded => $fld;
		}
	}

	# Check if wildcard '*' appears in accepted list
	my $has_wildcard = grep { $_ eq '*' } $ok->@*;

	if ($has_wildcard) {
		# Wildcard present: accept all remaining fields
		for my $fld (keys %args) {
			$filtered->{$fld} = delete $args{$fld};
		}
	}
	else {
		# Track but don't include if not on @accepted list
		for my $fld ($ok->@*) {
			if ( exists $args{$fld} ) {
				$filtered->{$fld} = delete $args{$fld};
			}
		}
	}

	my @unrecognized	= keys %args;	# Everything left
	if ( $db and @unrecognized > 0 ) {
		push @warnings => "Ignoring unrecognized arguments: " .
			join ', ' => map { "'$_'" } @unrecognized;
	}
	if ( $db and @excluded > 0 ) {
		push @warnings => "Ignoring excluded arguments: " .
			join ', ' => map { "'$_'" } @excluded;
	}

	# Combine parsing messages (always) with debug warnings (if debug mode)
	my @all_msgs	= (@messages, @warnings);
	my $return_msg	= @all_msgs
		? join "\n" => @all_msgs
		: "Admitted";

	return wantarray ? ( $filtered, $return_msg ) : $filtered;
}

=head1 RETURN VALUES

Both L</filter> and L</apply> return different values depending on context:

=head2 Success

=over 4

=item * List context: C<(hashref, "Admitted")> or C<(hashref, warning_message)>

=item * Scalar context: Hashref with filtered parameters

=back

=head2 Failure

=over 4

=item * List context: C<(undef, error_message)>

=item * Scalar context: C<undef>

=back

=head2 Common Status Messages

=over 4

=item * "Admitted" - All required fields present, filtering successful

=item * "Plain text argument accepted with key '_': '...'" - Parsing message (always shown)

=item * "Odd number of arguments provided; last element 'X' converted to flag with value 1" - Parsing message (always shown)

=item * "Ignoring excluded arguments: 'field1', 'field2'..." - Debug message (debug mode only)

=item * "Ignoring unrecognized arguments: 'field1', 'field2'..." - Debug message (debug mode only)

=item * "Unable to initialize without required arguments: 'field1', 'field2'..." - Error

=back

=head1 FEATURES

=over 4

=item * **Dual interface** - Functional or OO usage

=item * **Fast-fail** - Returns immediately on missing required parameters

=item * **Fast-success** - Returns immediately if all required parameters are provided and no others are provided or will be accepted

=item * **Flexible input** - Accepts hashrefs, arrayrefs, or scalars

=item * **Wildcard support** - Use C<'*'> in accepted list to accept all fields

=item * **No value checking** - Only presence/absence of fields

=item * **Debug mode** - Optional warnings about unrecognized or excluded fields

=item * **Method chaining** - Modifier methods return C<$self>

=item * **Perl 5.40+** - Modern Perl with signatures and post-deref

=item * **No dependencies** - Only core Perl's L<Exporter>

=back

=head1 DEBUG MODE

Debug mode provides additional information about field filtering during development:

    my ($filtered, $msg) = filter(
        $input,
        ['name'],
        ['email'],
        ['password'],
        1,  # Enable debug mode
    );

Debug warnings (only shown when debug mode is enabled):

=over 4

=item * Excluded fields that were removed

=item * Unrecognized fields that were ignored

=back

Parsing messages (always shown, regardless of debug mode):

=over 4

=item * Plain text arguments accepted with key '_'

=item * Odd number of array elements converted to flags

=back

Parsing messages inform you about transformations the filter made to your input format.
These are always reported because they affect the structure of the returned data.
Debug warnings help you understand which fields were filtered out during development.

=head1 WILDCARD SUPPORT

The C<accepted> parameter supports a wildcard C<'*'> to accept all fields
(except those in C<excluded>).

=head2 Wildcard Usage

    # Accept all fields
    filter($input, [], ['*']);

    # Accept all except specific exclusions
    filter($input, [], ['*'], ['password', 'ssn']);

    # Required + all other fields
    filter($input, ['id', 'name'], ['*']);

=head2 Important Notes

=over 4

=item * C<'*'> is B<only special in the C<accepted> parameter>

=item * In C<required> or C<excluded>, C<'*'> is treated as a literal field name

=item * Empty C<[]> for accepted means "accept none beyond required"

=item * Multiple wildcards are redundant but harmless

=item * Exclusions are always removed before acceptance is processed

=back

=head2 Debugging Pattern

A common debugging pattern is to add C<'*'> to an existing accepted list:

    # Normal operation
    filter($input, ['id'], ['name', 'email']);

    # Debugging - see all inputs
    filter($input, ['id'], ['name', 'email', '*']);

Or, start with minimum to troubleshoot specific fields

    filter($input, ['id'], []);

    # then
    filter($input, ['id'], ['name']);

    # then
    filter($input, ['id'], ['email']);

    # then
    filter($input, ['id'], ['name', 'email']);

    # then
    filter($input, ['id'], ['*']);


=head1 EXAMPLES

=head2 Basic Form Validation

    use Params::Filter;    # auto-imports filter() subroutine

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

=head2 Reusable Filter for Multiple Data Sources

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

=head2 Environment-Specific Filtering

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

=head2 Security Filtering

    # Remove sensitive fields from user input
    my ($safe_data, $msg) = filter(
        $user_input,
        ['username', 'email'],           # required
        ['full_name', 'phone', 'bio'],    # accepted
        ['password', 'ssn', 'api_key'],   # excluded
    );

    # Result contains only safe fields
    # password, ssn, api_key are removed even if provided

=head2 Dynamic Configuration from File

    # Load filter rules from config file
    my $config = decode_json(`cat filters.json`);

    my $filter = Params::Filter->new_filter()
        ->set_required($config->{user_create}{required})
        ->set_accepted($config->{user_create}{accepted})
        ->set_excluded($config->{user_create}{excluded});

    # Apply to incoming data
    my ($filtered, $msg) = $filter->apply($api_data);

=head2 Data Segregation for Multiple Subsystems

A common pattern is splitting incoming data into subsets for different
handlers or storage locations. Each filter extracts only the fields needed
for its specific purpose, implementing security through compartmentalization.

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

    # Filters
    # Personal data - general user info (no sensitive data)
    my $person_filter = Params::Filter->new_filter({
        required => ['name', 'user_id', 'email'],
        accepted => ['address', 'city', 'state', 'zip', 'phone', 'occupation', 'position', 'education'],
        excluded => ['password', 'credit_card_number'],
    });

    # Business data - subscription and billing info
    my $biz_filter = Params::Filter->new_filter({
        required => ['user_id', 'subscription_term', 'credit_card_number', 'zip'],
        accepted => ['alt_card_number', 'billing_address', 'billing_zip', 'promo_code'],
        excluded => ['password'],
    });

    # Authentication data - only credentials
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
    if ($self->{DEBUG}) {
        my @warnings = grep { $_ ne 'Admitted' } ($pmsg, $bmsg, $amsg);
        warn "Params filter debug warnings:\n" . join("\n", @warnings) . "\n"
            if @warnings;
    }

    # Route each subset to appropriate handler
    $self->add_user($person_data);           # User profile
    $self->set_subscription($biz_data);       # Billing system
    $self->set_password($auth_data);          # Auth system

    # continue ...
B<Note>: The original C<$data> is not modified by any filter. Each call to
C<apply()> creates its own internal copy, so the same data can be safely
processed by multiple filters.

=head1 SEE ALSO

=over 4

=item * L<Params::Validate> - Full-featured parameter validation

=item * L<Data::Verifier> - Data structure validation

=item * L<JSON::Schema::Modern> - JSON Schema validation

=back

=head1 AUTHOR

Bruce Van Allen <bva@cruzio.com>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.
See L<perlartistic|https://dev.perl.org/licenses/artistic.html>.

=head1 COPYRIGHT

Copyright (C) 2026, Bruce Van Allen

=cut

1;
