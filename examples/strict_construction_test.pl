#!/usr/local/bin/perl
use v5.40;

$|=1;

use Params::Filter; # exports &strictly
use Local::Data;
my $ui = Local::Data->new();

our $STRICTLY_REQUIRED	= [qw/name email/];
our $STRICTLY_ACCEPTED	= [qw/phone address city state zip/];
our $STRICTLY_EXCLUDED	= [qw/ssn license card_number/];

say "Functional version:\n";

my $obj1	= filter({'TESTING' => 1, Ready => 'ok'},['TESTING'], [qw/Ready Preparing/]);
say "$_:\t$obj1->{$_}" for sort keys $obj1->%*;

say "\n==============";
my ($obj2,$msg3)	= filter( {
	'name' => 'BVA', 
	'email' => 'me@here.com', 
	'phone' => '427-555-9949',
	'city'	=> 'Los Angeles',
	'state'	=> 'CA',
	'zip'	=> '',
	'surf'	=> 'Up',
	'ssn'	=> '111-3245-90',
 }, $STRICTLY_REQUIRED, $STRICTLY_ACCEPTED,$STRICTLY_EXCLUDED,1);
say "$_:\t$obj2->{$_}" for sort keys $obj2->%*;

say "\n==============";
my ($obj5,$msg5)	= filter( {
	'name' => 'BVA', 
	'email' => 'me@here.com', 
	'phone' => '427-555-9949',
	'city'	=> 'Los Angeles',
	'state'	=> 'CA',
	'zip'	=> '',
	'surf'	=> 'Up',
	'ssn'	=> '111-3245-90',
 }, $STRICTLY_REQUIRED);
say "Only accepting required:";
say "$_:\t$obj5->{$_}" for sort keys $obj5->%*;
say $msg5;
say "\n==============";
say "OO Version:\n";

my $filter	= Local::Params::Strictly->new_filter({
	required => $STRICTLY_REQUIRED,
	accepted => $STRICTLY_ACCEPTED,
	excluded => $STRICTLY_EXCLUDED,
	DEBUG	 => 1,
});

# No name
my ($ready,$mssg)	= $filter->apply({
	'email' => 'yo@here.com', 
	'phone' => '333-555-3320',
	'city'	=> 'SF',
	'state'	=> 'CA',
	'zipcode'	=> '',
	'surf'	=> 'Up',
}); 
if ($ready) {
 	say "$_:\t$ready->{$_}" for sort keys $ready->%*;
} else {
	say $mssg;
}
say "\n================\n";

my $data1	= {
	'name' => 'BVA', 
	'email' => 'me@here.com', 
	'phone' => '111-555-2239',
	'city'	=> 'Los Angeles',
	'state'	=> 'CA',
	'zipcode'	=> '',
	'ssn'  => '444-9999-22',
	'card_number'	=> '2222-2222-1111-1111',
 };
 my $data2 = {
	'name'  => 'Lulu',
	'email' => 'yo@here.com', 
	'phone' => '774-555-3692',
	'city'	=> 'SF',
	'state'	=> 'CA',
	'zip'	=> '',
	'surf'	=> 'Up',
 };

for my $d ($data1,$data2) {
	my ($revData, $msg)	= $filter->apply($d);
	say "$_:\t$revData->{$_}" for sort keys $revData->%*;
	say $msg;
	say '======';
}

my ($data, $msg) 	= $filter->apply($data1);
say "$_:\t$data->{$_}" for sort keys $data->%*;
say $msg;

__DATA__
