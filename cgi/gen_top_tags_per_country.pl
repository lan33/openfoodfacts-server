#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

use Blogs::Config qw/:all/;
use Blogs::Store qw/:all/;
use Blogs::Index qw/:all/;
use Blogs::Display qw/:all/;
use Blogs::Tags qw/:all/;
use Blogs::Users qw/:all/;
use Blogs::Images qw/:all/;
use Blogs::Lang qw/:all/;
use Blogs::Mail qw/:all/;
use Blogs::Products qw/:all/;
use Blogs::Food qw/:all/;
use Blogs::Ingredients qw/:all/;
use Blogs::Images qw/:all/;
use Blogs::Lang qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;

# Generate a list of the top brands, categories, users, additives etc.

my @fields = qw (
brands 
categories
packaging 
origins
manufacturing_places 
ingredients 
labels 
nutriments
allergens
traces 
users
photographers
informers
correctors
checkers
additives
allergens
emb_codes
cities
purchase_places
stores
countries
ingredients_from_palm_oil
ingredients_that_may_be_from_palm_oil
status
unknown_nutrients
pnns_groups_2
pnns_groups_1
);

# also generate stats for categories




my %countries = ();
my $total = 0;

my @dates = ('created_t', 'completed_t');
my %countries_dates = ();
my %products = ();

#foreach my $l (values %lang_lc) {

my $l = 'en';
$lc = $l;





my %dates = ();


my $fields_ref = {code => 1};
my %tags = ();
my %countries_tags = ();

my %codes = ();
my %true_end = (); # 0;
my %true_start = (); # 100000000000000000;
my $complete = 0;
	
foreach my $tagtype (@fields) {
	$fields_ref->{$tagtype . "_tags"} = 1;
}

foreach my $country (keys %{$properties{countries}}, 'en:world') {
	$countries_tags{$country} = {};
	foreach my $tagtype (@fields) {
		$countries_tags{$country}{$tagtype} = {};
		$countries_tags{$country}{$tagtype . "_nutriments"} = {};
	}
	$dates{$country} = {};		
	$countries_dates{$country} = {};
	foreach my $date (@dates) {
		$dates{$country}{$date} = {};
		$countries_dates{$country}{$date} = {};
	}		

	$true_end{$country} = 0;
	$true_start{$country} = 100000000000000000;	
}


delete $fields_ref->{users_tags};
$fields_ref->{creator} = 1;
$fields_ref->{nutriments} = 1;
$fields_ref->{created_t} = 1;
$fields_ref->{complete} = 1;
$fields_ref->{completed_t} = 1;

$fields_ref->{nutriments} = 1;

	
my $cursor = $products_collection->query({'empty' => { "\$ne" => 1 }})->fields($fields_ref);
$total = $cursor->count();

	
print STDERR "$total products\n";


my %products_nutriments = ();
my %countries_categories = ();

while (my $product_ref = $cursor->next) {
	
	my $code = $product_ref->{code};
	if (not defined $codes{$code}) {
		$codes{$code} = 1;
	}
	else {
		$codes{$code} += 1;
		#print STDERR "code $code seen $codes{$code} times!\n";
	}	
	
	if ((defined $code) and (defined $product_ref->{nutriments})
		and (($product_ref->{nutriments}{alcohol} ne '') or
		(($product_ref->{nutriments}{energy} ne '')))) {
		
		$products_nutriments{$code} = {};
		foreach my $nid (keys %{$product_ref->{nutriments}}) {
			next if $nid =~ /_/;
			next if ($product_ref->{nutriments}{$nid} eq '');
			
			$products_nutriments{$code}{$nid} = $product_ref->{nutriments}{$nid . "_100g"};
		}				
	}

	
	foreach my $tagtype (@fields) {
	
		$tags{$tagtype} = {};
		$tags{$tagtype . "_nutriments"} = {};
	
		if ($tagtype eq 'users') {
			$tags{$tagtype}{$product_ref->{creator}}++;
		}
		elsif (defined $product_ref->{$tagtype . "_tags"}) {
			foreach my $tagid (@{$product_ref->{$tagtype . "_tags"}}) {
				$tags{$tagtype}{$tagid}++;
				
				if ($tagtype eq 'ingredients') {
					#print STDERR "code: $code - ingredient: $tagid \n";
				}
				
				# nutriment info?
				next if (not defined $product_ref->{nutriments});
				next if (not defined $product_ref->{nutriments}{energy});
				next if (not defined $product_ref->{nutriments}{proteins});
				next if (not defined $product_ref->{nutriments}{carbohydrates});
				next if (not defined $product_ref->{nutriments}{fat});
				$tags{$tagtype . "_nutriments"}{$tagid}++;
				

			}
		}
		
		foreach my $country (@{$product_ref->{countries_tags}}, 'en:world') {
		
			foreach my $tagid (keys %{$tags{$tagtype}}) {
				$countries_tags{$country}{$tagtype}{$tagid} += $tags{$tagtype}{$tagid};
				
				if ($tagtype eq 'categories') {
					defined $countries_categories{$country} or $countries_categories{$country} = {};
					defined $countries_categories{$country}{$tagid} or $countries_categories{$country}{$tagid} = {};
					$countries_categories{$country}{$tagid}{$code} = 1;
				}
			}
			foreach my $tagid (keys %{$tags{$tagtype . "_nutriments"}}) {
				$countries_tags{$country}{$tagtype . "_nutriments"}{$tagid} += $tags{$tagtype . "_nutriments"}{$tagid};
			}				
		}
	}
	
	foreach my $country (@{$product_ref->{countries_tags}}, 'en:world') {
	
		$countries{$country}++;
	
		foreach my $date (@dates) {
			# print "dates products $lc $date : " . $product_ref->{$date} . "\n";
			if ((defined $product_ref->{$date}) and ($product_ref->{$date} > 0)) {
				$dates{$country}{$date}{int($product_ref->{$date} / 86400)}++;
				if ($product_ref->{$date} / 86400 > $true_end{$country}) {
					$true_end{$country} = int($product_ref->{$date} / 86400);
				}
				if ($product_ref->{$date} / 86400 < $true_start{$country}) {
					$true_start{$country} = int($product_ref->{$date} / 86400);
				}				
			}
		}
		$products{$country}++;		
	}
	
	if (($product_ref->{complete} > 0) and ((not defined $product_ref->{completed_t}) or ($product_ref->{completed_t} <= 0)) ) {
		print "product $code - complete: $product_ref->{complete} , completed_t: $product_ref->{completed_t}\n";
	}
	elsif ($product_ref->{completed_t} > 0) {
		$complete++;
		print "completed products: $complete\n";
	}

	
}

foreach my $country (keys %{$properties{countries}}, 'en:world') {

	my $cc = lc($properties{countries}{$country}{"country_code_2:en"});
	if ($country eq 'en:world') {
		$cc = 'world';
	}
	
	# Category stats for nutriments
	
	my $min_products = 10;
	my %categories = ();	
	
	
	foreach my $tagid (keys %{$countries_categories{$country}}) {
	
		# Compute mean, standard deviation etc.
		
		my $count = 0;
		my $n = 0;
		my %nutriments = ();

		foreach my $code (keys %{$countries_categories{$country}{$tagid}}) {
		
			$count++;
		
			next if (not defined $products_nutriments{$code});
		
			$n++;
			
			foreach my $nid (keys %{$products_nutriments{$code}}) {
													
				add_product_nutriment_to_stats(\%nutriments, $nid, $products_nutriments{$code}{$nid});
			}	
		}
		
		if ($n >= $min_products) {
			
			($cc eq 'fr') and ($tagid =~ /taboul/) and print "compute_stats_for_products - fr - $tagid - n: $n - count: $count - min: $min_products\n";
			$categories{$tagid} = {};
			compute_stats_for_products($categories{$tagid}, \%nutriments, $count, $n, $min_products, $tagid);
		
		}		
	}

	store("$data_root/index/categories_nutriments_per_country.$cc.sto", \%categories);
	
	
	# Dates

	foreach my $date (@dates) {
		my @sorted_dates = sort ( {$dates{$country}{$date}{$a} <=> $dates{$country}{$date}{$b}} keys %{$dates{$country}{$date}});
		my $start = $sorted_dates[0];
		my $end = $sorted_dates[$#sorted_dates];
		
		# somehow we don't get the biggest day...
		if ($true_end{$country} > $end) {
			$end = $true_end{$country};
		}
		if ($true_start{$country} < $start) {
			$start = $true_start{$country};
		}	
		
		$countries_dates{$country}{$date . ".start"} = $start;
		$countries_dates{$country}{$date . ".end"} = $end;
		
		#print "dates_stats_$country countryid: $country - date: $date - start: $start - end: $end\n";
		
		my $current = 0;
		for (my $i = $start; $i <= $end; $i++) {
			$current += $dates{$country}{$date}{$i};
			$countries_dates{$country}{$date}{$i} = $current;
			#print "dates_current_$cc lc: $cc - date: $date - start: $start - end: $end - i: $i - $current\n";
		}
	}

	store("$data_root/index/countries/tags_count.$cc.sto", $countries_tags{$country});

	# generate a file for each official language + English;
	
	my @languages =  (split(",", $properties{countries}{$country}{"languages:en"}));
	if ($properties{countries}{$country}{"languages:en"} !~ /en/) {
		push @languages, 'en';
	}
	
	foreach my $language (@languages) {
	
	$lang = $language;
	$lc = $language;

	foreach my $tagtype (@fields) {

		my @tags;

		if (not defined $taxonomy_fields{$tagtype}) {
			@tags = sort ({$a cmp $b} keys %{$countries_tags{$country}{$tagtype}});
		}
		else {
			@tags = sort ( { ($countries_tags{$country}{$tagtype}{$b} <=> $countries_tags{$country}{$tagtype}{$a}) || ($a cmp $b)  } keys %{$countries_tags{$country}{$tagtype}});
		}
		
		my $html = "<h1>" . sprintf(lang("list_of_x"), $Lang{$tagtype . "_p"}{$lang}) . "</h1>";
		
		if (-e "$data_root/lang/$lc/texts/" . get_fileid($Lang{$tagtype . "_p"}{$lang}) . ".list.html") {
			open (IN, "< $data_root/lang/$lc/texts/" . get_fileid($Lang{$tagtype . "_p"}{$lang}) . ".list.html");
			$html .= join("\n", (<IN>));
			close IN;
		}
		
		$html .= "<p>" . ($#tags + 1) . " ". $Lang{$tagtype . "_p"}{$lang} . ":</p>";
		
		print "tagtype: $tagtype - " . $Lang{$tagtype . "_p"}{$lang} . " - count: " . ($#tags + 1) . "\n";
		
		my $th_nutriments = '';
		
		if ($tagtype eq 'categories') {
			$th_nutriments = "<th>" . ucfirst($Lang{"products_with_nutriments"}{$lang}) . "</th>";
		}
		
		if ($tagtype eq 'categories') {
			$th_nutriments .= "<th>*</th>";
		}		
		
		if ($tagtype eq 'additives') {
			$th_nutriments .= "<th>" . lang("risk_level") . "</th>";
		}
		
		$html .= "<div style=\"max-width:600px;\"><table id=\"tagstable\">\n<thead><tr><th>" . ucfirst($Lang{$tagtype . "_s"}{$lang}) . "</th><th>" . ucfirst($Lang{"products"}{$lang}) . "</th>" . $th_nutriments . "</tr></thead>\n<tbody>\n";

#var availableTags = [
#      "ActionScript",
#      "Scala",
#      "Scheme"
#    ];		
		my $js = <<JS
var ${tagtype}Tags = [
JS
;
		
		foreach my $tagid (@tags) {
			
			my $link;
			my $products = $countries_tags{$country}{$tagtype}{$tagid};
			if ($products == 0) {
				$products = "";
			}

			my $td_nutriments = '';
			if ($tagtype eq 'categories') {
				$td_nutriments .= "<td style=\"text-align:right\">" . $countries_tags{$country}{$tagtype . "_nutriments"}{$tagid} . "</td>";
			}
			
			# known tag?
			if ($tagtype eq 'categories') {
				if ((defined $canon_tags{$lc}) and (defined $canon_tags{$lc}{$tagtype}) and (defined $canon_tags{$lc}{$tagtype}{$tagid})) {
					$td_nutriments .= "<td></td>";
				}
				else {
					$td_nutriments .= "<td style=\"text-align:center\">*</td>";
				}
			}
			
			my $link = canonicalize_tag_link($tagtype, $tagid);
			
			my $info = '';
			my $extra_td = '';
			
			if ($tagtype eq 'additives') {
				if ($tags_levels{$lc}{$tagtype}{$tagid}) {
					# $info = ' class="additives_' . $ingredients_classes{$tagtype}{$tagid}{level} . '" title="' . $ingredients_classes{$tagtype}{$tagid}{warning} . '" ';
					my $risk_level = lang("risk_level_" . $tags_levels{$lc}{$tagtype}{$tagid});
					$risk_level =~ s/ /\&nbsp;/g;
					$extra_td = '<td class="level_' . $tags_levels{$lc}{$tagtype}{$tagid} . '">' . $risk_level . '</td>';
				}
				else {
					#$extra_td = '<td class="additives_0">' . lang("risk_level_0") . '</td>';				
					$extra_td = '<td></td>';
				}
			}
			
				if ((defined $tags_levels{$lc}{$tagtype}) and (defined $tags_levels{$lc}{$tagtype}{$tagid})) {
					$info = ' class="level_' . $tags_levels{$lc}{$tagtype}{$tagid} . '" ';
				}			
			
			if (defined $taxonomy_fields{$tagtype}) {
				$html .= "<tr><td>" . display_taxonomy_tag_link($lc,$tagtype,$tagid) . "</td><td style=\"text-align:right\">$products</td>" . $td_nutriments . $extra_td . "</tr>\n";
				$js .= "\n\"" . display_taxonomy_tag($lc,$tagtype, $tagid) . "\",";
			}
			else {
			
				$html .= "<tr><td><a href=\"$link\"$info>" . canonicalize_tag2($tagtype, $tagid) . "</a></td><td style=\"text-align:right\">$products</td>" . $td_nutriments . $extra_td . "</tr>\n";
			$js .= "\n\"" . canonicalize_tag2($tagtype, $tagid) . "\",";
			}
		}
		
		$html .= "</tbody></table></div>";
		
		if ($tagtype eq 'categories') {
			$html .= "<p>La colonne * indique que la catégorie ne fait pas partie de la hiérarchie de la catégorie. S'il y a une *, la catégorie n'est pas dans la hiérarchie.</p>";
		}
		
		my $tagtype_p = $Lang{$tagtype . "_p"}{$lang};
		
		$html .= <<HTML
<initjs>
oTable = \$('#tagstable').dataTable({
	"bJQueryUI": true,
	"bPaginate": false,
	"aaSorting": [],
	"oLanguage": {
		"sSearch": "$Lang{tagstable_search}{$lang}",
		"sInfo": "_TOTAL_ $tagtype_p",
		"sInfoFiltered": " - $Lang{tagstable_filtered}{$lang}"
	}
});
</initjs>
<scripts>
<script src="/js/jquery.dataTables.min.js"></script>
</scripts>
<header>
<link rel="stylesheet" href="/js/datatables.css" />
</header>
HTML
;
		
		 open (OUT, ">:encoding(UTF-8)", "$data_root/lists/" . get_fileid(lang($tagtype . "_p")) . ".$cc.$lang.html");
		 print OUT $html;
		 close OUT;
		 
		$js =~ s/,$//;
		$js .= <<JS
];
JS
;

		(-e "$www_root/js/countries/$cc") or mkdir ("$www_root/js/countries/$cc", 0755);
		(-e "$www_root/js/countries/$cc/$lang") or mkdir ("$www_root/js/countries/$cc/$lang", 0755);
		 open (OUT, ">:encoding(UTF-8)", "$www_root/js/countries/$cc/$lang$tagtype.js");
		 print OUT $js;
		 close OUT;
		 
		 
	}
	} # languages
}


my $html = "<p>$total products:</p>";
foreach my $country (sort { $countries{$b} <=> $countries{$a}} keys %countries) {

        if ($countries{$country} > 0) {
				$l = "en";
				$lc = $l;
                $lang = $l;
				my $cc = lc($properties{countries}{$country}{"country_code_2:en"});
				if ($country eq 'en:world') {
					$cc = 'world';
				}				
                $html .= "<a href=\"http://$cc.$domain/\">" . display_taxonomy_tag_link('en','countries',$country) . "</a> : $countries{$country} " . lang("products") . "<br />";
        }

}

open (OUT, ">:encoding(UTF-8)", "$www_root/countries.html");
print OUT $html;
close OUT;


my $html = "";
my $c = 0;
foreach my $country (sort { $countries{$b} <=> $countries{$a}} keys %countries) {

        if ($countries{$country} > 0) {
				my $cc = lc($properties{countries}{$country}{"country_code_2:en"});
				if ($country eq 'en:world') {
					$cc = 'world';
				}
				$cc ne '' or next;
				$c++;
				
				my $n = $countries{$country};
				$n =~ s/(\d)(?=(\d{3})+$)/$1/g;
				my $link = "<a href=\"http://$cc.$domain/\">" . display_taxonomy_tag('en','countries',$country) . "</a>";
				my $i = 0;
				foreach my $lc (@{$country_languages{$cc}}) {
					if ($lc ne 'en') {
						my $subdomain = $cc;
						if ($i != 0) {
							$subdomain = "$cc-$lc";
						}
						$link .= " / " . "<a href=\"http://$subdomain.$domain/\">" . display_taxonomy_tag($lc,'countries',$country) . "</a>"
					}

					$i++;
				}
		
					if ($link =~ / \/ /) {
						$link =~ s/ \/ / \(/;
						$link .= ")";
					}
		
                $html .= "<li>$link - " . $countries{$country} . " " . lang("products") . "</li>\n";
        }

}
$html =~ s/ - $//;
$html =~ s/ 1 products/ 1 product/g;

$html = "<p>$total products sold in $c countries and territories:</p>\n<ul>\n$html</ul>\n";

open (OUT, ">:encoding(UTF-8)", "$www_root/products_countries.html");
print OUT $html;
close OUT;


# ! Open Beauty Facts

if ($domain eq 'openfoodfacts.org') {

open (DEBUG, ">:encoding(UTF-8)", "/home/yogurt/html/yogurts_debug");

my $html = "";
my $c = 0;
foreach my $country (sort { $countries_tags{$b}{categories}{"en:yogurts"} <=> $countries_tags{$a}{categories}{"en:yogurts"}} keys %countries) {

		print DEBUG "yogurts - $country - " . $countries_tags{$country}{categories}{"en:yogurts"} . "\n";
		print STDERR "yogurts - $country - " . $countries_tags{$country}{categories}{"en:yogurts"} . "\n";
        if ($countries_tags{$country}{categories}{"en:yogurts"}  > 0) {
				my $cc = lc($properties{countries}{$country}{"country_code_2:en"});
				if ($country eq 'en:world') {
					$cc = 'world';
				}
				$lc = $country_languages{$cc}[0]; # first official language
		
				if (not exists $Langs{$lc}) {
					$lc = 'en';
				}
				
				print DEBUG "yogurts - cc: $cc - lc: $lc \n";
				
				$cc ne '' or next;
				$c++;
				
				my $n = $countries_tags{$country}{categories}{"en:yogurts"};
				$n =~ s/(\d)(?=(\d{3})+$)/$1/g;
				my $link = "<a href=\"http://$cc.$domain" . canonicalize_taxonomy_tag_link($lc,"categories", "en:yogurts") . "\">" . display_taxonomy_tag('en','countries',$country) . "</a>";

		
                $html .= "<li>$link - " . $countries_tags{$country}{categories}{"en:yogurts"} . " yogurts</li>\n";
        }

}
$html =~ s/ 1 yogurts/ 1 yogurt/g;

my $yogurts = $countries_tags{"en:world"}{categories}{"en:yogurts"};


$html = "<h2 style=\"color:white\">$yogurts yogurts opened so far!</h2>\n<p>$yogurts yogurts sold in $c countries and territories:</p>\n<ul>\n$html</ul>\n";

open (OUT, ">:encoding(UTF-8)", "/home/yogurt/html/yogurts_countries.html");
print OUT $html;
close OUT;

close DEBUG;

}

# Number of products and complete products

foreach my $country (sort { $countries{$b} <=> $countries{$a}} keys %countries) {

	my $cc = lc($properties{countries}{$country}{"country_code_2:en"});
	if ($country eq 'en:world') {
		$cc = 'world';
	}
	
	my $meta = '';
	if (-e "$www_root/images/misc/products_graph_country_$cc.png") {
		$meta = <<HTML
<meta property="og:image" content="http://$lc.openfoodfacts.org/images/misc/products_graph_country_$cc.png"/>
HTML
;
		print "found meta products_graph_country_$cc.png image\n";
	}

	
	foreach my $lc (@{$country_languages{$cc}}) {
	
	$lang = $lc;

	my $series = '';
	
	my $end = 0;
	my $start = 100000000000;
	
	foreach my $date (@dates) {
		if ($countries_dates{$country}{$date . ".start"} < $start) {
			$start = $countries_dates{$country}{$date . ".start"};
		}
		if ($countries_dates{$country}{$date . ".end"} > $end) {
			$end = $countries_dates{$country}{$date . ".end"};
		}
	}	

	foreach my $date (@dates) {
		my @sorted_dates = sort ( {$countries_dates{$country}{$date}{$a} <=> $countries_dates{$country}{$b}} keys %{$countries_dates{$country}{$date}});

		my $series_start = $countries_dates{$country}{$date . ".start"};
		my $series_end = $countries_dates{$country}{$date . ".end"};
		

		
		my $name = $Lang{"products_stats_$date"}{$lang};
		my $series_point_start = $series_start * 86400 * 1000;
		$series .= <<HTML
{
	name: '$name',
	pointInterval: 24 * 3600 * 1000,
    pointStart: $series_point_start,	
	data: [
HTML
;
		
		my $current = 0;
		my $i = 0;
		for (my $t = $series_start ; $t < $end; $t++) {
			if (defined $countries_dates{$country}{$date}{$t}) {
				$current = $countries_dates{$country}{$date}{$t};
			}
			$series .= $current . ', ';
			$i++;
			if ($i % 10 == 0) {
				$series =~ s/ $/\n/;
			}
		}
		$series =~ s/,\n?$//;
		$series .= "\n]\n},\n";
	}
	
	$series =~ s/,\n$//;

	my $country_name = display_taxonomy_tag($lang,'countries',$country);
	
	my $html = <<HTML
<initjs>

Highcharts.setOptions({
	lang: {
		months: $Lang{months}{$lang},
		weekdays: $Lang{weekdays}{$lang}
	}
});

        \$('#container').highcharts({
            chart: {
                type: 'area'
            },
            title: {
                text: '$Lang{products_stats}{$lang} - $country_name'
            },
            subtitle: {
                text: 'Source: <a href="http://$cc.openfoodfacts.org">'+
                    '$cc.openfoodfacts.org</a>'
            },
            xAxis: {
		        type: 'datetime',	
            },
            yAxis: {
                title: {
                    text: '$Lang{products_p}{$lang}'
                },
                labels: {
                    formatter: function() {
                        return this.value;
                    }
                }
            },
			tooltip: {
                shared: true
			},
            plotOptions: {
                area: {
                    //pointStart: 1940,
                    marker: {
                        enabled: false,
                        symbol: 'circle',
                        radius: 2,
                        states: {
                            hover: {
                                enabled: true
                            }
                        }
                    }
                }
            },
            series: [
$series
			]
        });

</initjs>   

<scripts>
<script src="/js/highcharts.js"></script></scripts>
<header>
$meta
</header>
 	
<div id="container" style="height: 400px"></div>
	
HTML
;	

	print "products_stats - saving $data_root/lang/$lang/texts/products_stats_$cc.html\n";
	open (OUT, ">:encoding(UTF-8)", "$data_root/lang/$lang/texts/products_stats_$cc.html");
	print OUT $html;
	close OUT;

}
}



# All languages

# Number of products and complete products

my $date = "created_t";


	my $series = '';
	
	my $end = 0;
	my $start = 100000000000;
	
	foreach my $country (sort { $countries{$b} <=> $countries{$a}} keys %countries) {
	
		if ($countries_dates{$country}{$date . ".start"} < $start) {
			$start = $countries_dates{$country}{$date . ".start"};
		}
		if ($countries_dates{$country}{$date . ".end"} > $end) {
			$end = $countries_dates{$country}{$date . ".end"};
		}
	}	

	foreach my $country (sort  { $countries_dates{$a}{$date . ".start"} <=> $countries_dates{$b}{$date . ".start"} } keys %countries) {

	$lang = $lc;	
	
		my @sorted_dates = sort ( {$countries_dates{$country}{$date}{$a} <=> $countries_dates{$country}{$b}} keys %{$countries_dates{$country}{$date}});

		my $series_start = $countries_dates{$country}{$date . ".start"};
		my $series_end = $countries_dates{$country}{$date . ".end"};
		
		next if $series_start < 100;
		
		my $name = $Langs{$lc};
		my $series_point_start = $series_start * 86400 * 1000;
		$series .= <<HTML
{
	name: '$name',
	pointInterval: 24 * 3600 * 1000,
    pointStart: $series_point_start,	
	data: [
HTML
;
		
		my $current = 0;
		my $i = 0;
		for (my $t = $series_start ; $t < $end; $t++) {
			if (defined $countries_dates{$country}{$date}{$t}) {
				$current = $countries_dates{$country}{$date}{$t};
			}
			$series .= $current . ', ';
			$i++;
			if ($i % 10 == 0) {
				$series =~ s/ $/\n/;
			}
		}
		$series =~ s/,\n?$//;
		$series .= "\n]\n},\n";
	}
	
	$series =~ s/,\n$//;


	$lang = 'en';
	$lc = 'en';
	
	my $html = <<HTML


        \$('#container').highcharts({
            chart: {
                type: 'area'
            },
            title: {
                text: '$Lang{products_stats}{$lang}'
            },
            subtitle: {
                text: 'Source: <a href="http://openfoodfacts.org">'+
                    'openfoodfacts.org</a>'
            },
			tooltip: {
                shared: true
			},
            xAxis: {
		        type: 'datetime',	
            },
            yAxis: {
                title: {
                    text: '$Lang{products_p}{$lang}'
                },
                labels: {
                    formatter: function() {
                        return this.value;
                    }
                }
            },
            plotOptions: {
                area: {
                    stacking: 'normal',
                    marker: {
                        enabled: false,
                        symbol: 'circle',
                        radius: 2,
                        states: {
                            hover: {
                                enabled: true
                            }
                        }
                    }
                }
            },
            series: [
$series
			]
        });

	
HTML
;	

	open (OUT, ">:encoding(UTF-8)", "$www_root/products_countries.js");
	print OUT $html;
	close OUT;





exit(0);
