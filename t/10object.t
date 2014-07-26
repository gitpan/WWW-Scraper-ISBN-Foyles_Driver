#!/usr/bin/perl -w
use strict;

use Data::Dumper;
use Test::More tests => 32;
use WWW::Scraper::ISBN;

###########################################################

my $DRIVER          = 'Foyles';
my $CHECK_DOMAIN    = 'www.google.com';

my %tests = (
    '1558607013' => [
        [ 'is',     'isbn',         '9781558607019'                 ],
        [ 'is',     'isbn10',       '1558607013'                    ],
        [ 'is',     'isbn13',       '9781558607019'                 ],
        [ 'is',     'ean13',        '9781558607019'                 ],
        [ 'is',     'title',        'Higher-Order Perl: Transforming Programs with Programs'    ],
        [ 'like',   'author',       qr|Dominus|                     ],
        [ 'is',     'publisher',    'Morgan Kaufmann Publishers Inc.' ],
        [ 'is',     'pubdate',      '28/03/2005'                    ],
        [ 'is',     'binding',      'Paperback'                     ],
        [ 'like',   'image_link',   qr|http://images.foyles.co.uk/large/books/img[/\d]+.jpg|    ],
        [ 'like',   'thumb_link',   qr|http://images.foyles.co.uk/large/books/img[/\d]+.jpg|    ],
        [ 'like',   'description',  qr|Most Perl programmers were originally trained as C and Unix programmers,| ],
        [ 'like',   'book_link',    qr|http://www.foyles.co.uk/witem/computing-it/higherorder-perl-transforming.*?9781558607019| ]
    ],
    '9780571239566' => [
        [ 'is',     'isbn',         '9780571239566'                 ],
        [ 'is',     'isbn10',       '0571239560'                    ],
        [ 'is',     'isbn13',       '9780571239566'                 ],
        [ 'is',     'ean13',        '9780571239566'                 ],
        [ 'is',     'title',        'Touching from a Distance'      ],
        [ 'is',     'author',       'Deborah Curtis'                ],
        [ 'is',     'publisher',    'Faber and Faber'               ],
        [ 'is',     'pubdate',      '04/10/2007'                    ],
        [ 'is',     'binding',      'Paperback'                     ],
        [ 'like',   'image_link',   qr!http://(images.foyles.co.uk/large/books/img[/\d]+.jpg|images.alibris.com/isbn/[/\d]+.gif)!    ],
        [ 'like',   'thumb_link',   qr!http://(images.foyles.co.uk/large/books/img[/\d]+.jpg|images.alibris.com/isbn/[/\d]+.gif)!    ],
        [ 'like',   'description',  qr|Ian Curtis left behind a legacy rich in artistic genius| ],
        [ 'like',   'book_link',    qr!http://www.foyles.co.uk/(witem/biography|mpitem/marketplace)/touching-from-a-distance,deborah-curtis-9780571239566! ]
    ],
);

my $tests = 0;
for my $isbn (keys %tests) { $tests += scalar( @{ $tests{$isbn} } ) + 2 }

###########################################################

my $scraper = WWW::Scraper::ISBN->new();
isa_ok($scraper,'WWW::Scraper::ISBN');

SKIP: {
	skip "Can't see a network connection", $tests+1   if(pingtest($CHECK_DOMAIN));

	$scraper->drivers($DRIVER);

    # this ISBN doesn't exist
	my $isbn = "0987654321";
    my $record;
    eval { $record = $scraper->search($isbn); };
    if($record && $record->found) {
        ok(0,'Unexpectedly found a non-existent book');
    } elsif($record) {
        like($record->error,qr/Invalid ISBN specified/);
    } else {
        like($@,qr/Invalid ISBN specified/);
    }

    for $isbn (keys %tests) {
        eval { $record = $scraper->search($isbn) };
        my $error = $@ || $record->error || '';

        SKIP: {
            skip "Website unavailable", scalar(@{ $tests{$isbn} }) + 2   
                if($error =~ /website appears to be unavailable/);
            skip "Book unavailable", scalar(@{ $tests{$isbn} }) + 2   
                if($error =~ /Failed to find that book/ || !$record->found);

            unless($record && $record->found) {
                diag("Failed to create record: $error");
                next;
            }

            is($record->found,1);
            is($record->found_in,$DRIVER);

            my $fail = 0;
            my $book = $record->book;
            for my $test (@{ $tests{$isbn} }) {
                if($test->[0] eq 'ok')          { $fail += ! ok(       $book->{$test->[1]},             ".. '$test->[1]' found [$isbn]"); } 
                elsif($test->[0] eq 'is')       { $fail += ! is(       $book->{$test->[1]}, $test->[2], ".. '$test->[1]' found [$isbn]"); } 
                elsif($test->[0] eq 'isnt')     { $fail += ! isnt(     $book->{$test->[1]}, $test->[2], ".. '$test->[1]' found [$isbn]"); } 
                elsif($test->[0] eq 'like')     { $fail += ! like(     $book->{$test->[1]}, $test->[2], ".. '$test->[1]' found [$isbn]"); } 
                elsif($test->[0] eq 'unlike')   { $fail += ! unlike(   $book->{$test->[1]}, $test->[2], ".. '$test->[1]' found [$isbn]"); }
            }

            diag("book=[".Dumper($book)."]")    if($fail);
        }
    }
}

###########################################################

# crude, but it'll hopefully do ;)
sub pingtest {
    my $domain = shift or return 0;
    my $cmd =   $^O =~ /solaris/i                           ? "ping -s $domain 56 1" :
                $^O =~ /dos|os2|mswin32|netware|cygwin/i    ? "ping -n 1 $domain "
                                                            : "ping -c 1 $domain >/dev/null 2>&1";

    eval { system($cmd) }; 
    if($@) {                # can't find ping, or wrong arguments?
        diag($@);
        return 1;
    }

    my $retcode = $? >> 8;  # ping returns 1 if unable to connect
    return $retcode;
}
