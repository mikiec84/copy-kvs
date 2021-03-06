
use strict;
use warnings;

require 't/test_helpers.inc.pl';

# NoWarnings test fails because of Net::Amazon::S3:
#
#     Passing a list of values to enum is deprecated. Enum values should be
#     wrapped in an arrayref. at /System/Library/Perl/Extras/5.18/darwin-thread
#     -multi-2level/Moose/Util/TypeConstraints.pm line 442.
#
# use Test::NoWarnings;

use Test::More tests => 2;
use Test::Deep;

BEGIN
{
    use FindBin;
    use lib "$FindBin::Bin/../lib";

    use CopyKVS;
    use CopyKVS::Handler::GridFS;
}

use File::Slurp;

# Connection configuration
my $config = configuration_from_env();

# Rename backup / restore files to not touch the "production" ones
$config->{ lock_file } .= random_string( 32 );

my $test_bucket_name          = 'gridfs-to-s3.testing.' . random_string( 32 );
my $test_source_database_name = 'gridfs-to-s3_testing_source_' . random_string( 16 );

# Create the lock file, expect subroutines to fail with non-zero exit code
write_file( $config->{ lock_file }, '1' );

# Copy files from source GridFS database to S3
$config->{ connectors }->{ "mongodb_gridfs_test" }->{ database } = $test_source_database_name;
$config->{ connectors }->{ "amazon_s3_test" }->{ bucket_name }   = $test_bucket_name;
eval { CopyKVS::copy_kvs( $config, 'mongodb_gridfs_test', 'amazon_s3_test' ); };
my $error_message = $@;
ok( $error_message,                 "Copy from source GridFS to S3 while lock file is present: $error_message" );
ok( $error_message =~ /^Lock file/, "Copy subroutine complains about lock file being present: $error_message" );

unlink( $config->{ lock_file } );
