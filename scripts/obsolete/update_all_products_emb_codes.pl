#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Images qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;


# Get a list of all products


my $cursor = $products_collection->query({})->fields({ code => 1 });;
my $count = $cursor->count();
	
	print STDERR "$count products to update\n";
	
	while (my $product_ref = $cursor->next) {
        
		
		my $code = $product_ref->{code};
		my $path = product_path($code);
		
		# print STDERR "updating product $code\n";
		
		$product_ref = retrieve_product($code);
		
		if ((defined $product_ref) and ($code ne '')) {
		
		$lc = $product_ref->{lc};
		
		# Update
		my $field = 'emb_codes';
		$product_ref->{emb_codes} = $product_ref->{emb_code};
		next if $product_ref->{emb_codes} eq '';
		
			if ($field eq 'emb_codes') {
				# French emb codes
				$product_ref->{emb_codes_orig} = $product_ref->{emb_codes};
				$product_ref->{$field} = uc($product_ref->{$field});
				$product_ref->{$field} =~ s/(^|,|, )(emb|e)?(\s|-|_|\.)?(\d+)(\.|-|\s)?(\d+)(\.|_|\s|-)?([a-z]+)/$1EMB $4$6$8/ig;
				
				# FRANCE -> FR
				$product_ref->{$field} =~ s/(^|,|, )(france)/$1FR/ig;
				
				sub normalize_emb_ce_code($$) {
					my $country = shift;
					my $number = shift;
					$country = uc($country);
					$number =~ s/\D//g;
					$number =~ s/^(\d\d)(\d\d\d)(\d)/$1.$2.$3/;
					$number =~ s/^(\d\d)(\d\d)/$1.$2/;
					
					# put leading 0s at the end
					$number =~ s/\.(\d)$/\.00$1/;
					$number =~ s/\.(\d\d)$/\.0$1/;
					return "$country $number CE";
				}
				
				# CE codes -- FR 67.145.01 CE
				$product_ref->{$field} =~ s/(^|,|, )([a-z][a-z])(\s|-|_|\.)?((\d|\.|_|\s|-)+)(\.|_|\s|-)?(ce)\b/$1 . normalize_emb_ce_code($2,$4)/ieg;				
			}
			print "emb - code: $code - $product_ref->{emb_code} -> $product_ref->{$field}\n";
			if ($product_ref->{$field} =~/,/) {
				print "multiple codes - code: $code - field: $field = $product_ref->{$field}\n";
			}

				$product_ref->{$field . "_tags" } = [];
				if ($field eq 'emb_codes') {
					$product_ref->{"cities_tags" } = [];
				}
				foreach my $tag (split(',', $product_ref->{$field} )) {
					if (get_fileid($tag) ne '') {
						push @{$product_ref->{$field . "_tags" }}, get_fileid($tag);
						if ($field eq 'emb_codes') {
							my $city_code = get_city_code($tag);
							if (defined $emb_codes_cities{$city_code}) {
								push @{$product_ref->{"cities_tags" }}, get_fileid($emb_codes_cities{$city_code}) ;
							}
						}
					}
				}
	
		
		# Store

		store("$data_root/products/$path/product.sto", $product_ref);		
		$products_collection->save($product_ref);
		
		}
	}

exit(0);
