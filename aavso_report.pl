#!/usr/bin/perl
# --------------------------------------------------------------------------------------------------------------------
# ????????.? Matt created program
# 20120703.1 jadv scrubbed program
# --------------------------------------------------------------------------------------------------------------------
# invoke this program using the following command line
# ./aavso_report.pl obsconst_2017.dat aavso.srt results.txt
# --------------------------------------------------------------------------------------------------------------------
	use warnings; # modern practice is to use this "pragma" rather than the "-w" flag
	use strict; # good Perl programming practice is to always use "strict" to enforce good behavior
# --------------------------------------------------------------------------------------------------------------------
# read in observer characteristic data
	my %observer_data;	# data is held in a hash, keyed to the observer code
	
    open(observer_data_file, "<", $ARGV[0]);	# use the file name defined by the first command line argument
    
    while (my $observer_line = <observer_data_file>) {
        chomp($observer_line);
        
        my $observer_code = substr($observer_line, 0, 4);
        my $k_factor = substr($observer_line, 8, 7);
        my $weight_flag = substr($observer_line, 17, 7) || 0;
		my $observer_name = substr($observer_line, 24, length($observer_line) - 24);

        $observer_code =~ s/\s//g;	# remove all spaces
        
        $k_factor =~ s/\s//g;
        $k_factor = 1 if $k_factor eq "";	# if field is empty then use value of 1.0
        
        $observer_name =~ s/(^\s+)|(\s+$)//;

        my $observer_record = {
            k_factor => $k_factor,
            name => $observer_name,
            observation_count => 0
        };
        
        $observer_data{$observer_code} = $observer_record;
#        printf("% 4s|%5.4f|%s\n", $observer_code, $k_factor, $observer_name);	# uncomment to review observer records
    }
    
    close(observer_data_file);
# --------------------------------------------------------------------------------------------------------------------
# read in raw solar data
	my %solar_data;	# this is a complicated record - a hash keyed on julian date, each element containing an array of records, one for each observer
	my %daily_solar_observation_count;

	open(solar_data_file, "<", $ARGV[1]);
	
	# read and discard the header line from the file
	my $solar_data_line = <solar_data_file>;
	
	while ($solar_data_line = <solar_data_file>) {
		chomp($solar_data_line);
		$solar_data_line =~ s/\|.*$//;
		$solar_data_line =~ s/-.----/1.0000/g;
		my @solar_data_array = split(" ", $solar_data_line, 10);
		
	    my $julian_date = $solar_data_array[0];
	    my $solar_data_record = {
	        group_number => $solar_data_array[1] || 0,
	        sunspot_number => $solar_data_array[2] || 0,
	        observer_code => $solar_data_array[8] || "",
	    };
	    $daily_solar_observation_count{$julian_date} = 0;
	    
	    push(@{$solar_data{$julian_date}}, $solar_data_record);
#        printf("%9.4f|% 4s|% 3d|% 3d\n", $julian_date, $solar_data_array[8], $solar_data_array[1], $solar_data_array[2]);	# uncomment to review solar records
	}

	close(solar_data_file);
# --------------------------------------------------------------------------------------------------------------------
# process the accumulated data
	open(results_file, ">", $ARGV[2]);

	printf(results_file "% 10s % 10s % 10s % 10s % 10s % 10s\n", "     JDay ", "      #Obs", "    Wolf_# ", " Wolf_Std ", "Scaled_SSN ", "Scaled_Std");
	
	# process observation data and emit it by day
	my $total_observation_count = 0;
	my %daily_observer_count;
	foreach my $julian_date (sort(keys(%solar_data))) {
		my $data_count = 0;
		my ($data_sum, $data_sum_squared, $data_average, $data_stddev) = (0, 0, 0, 0);
		my ($adjusted_data_sum, $adjusted_data_sum_squared, $adjusted_data_average, $adjusted_data_stddev) = (0, 0, 0, 0);
		my ($weight_sum, $weight_sum_squared, $weight_average, $weight_stddev) = (0, 0, 0, 0);
		my $weighted_log_data_count = 0;
		my ($weighted_log_data_sum, $weighted_log_data_sum_squared, $weighted_log_data_average, $weighted_log_data_stddev) = (0, 0, 0, 0);
		
		foreach my $solar_data_record (@{$solar_data{$julian_date}}) {
			my $observer_code = $solar_data_record->{observer_code};
			if (!exists($observer_data{$observer_code})) {
				printf("ERROR - observer code '% 4s' not found in observer data - record ignored.\n", $observer_code);
				next;
			}

			# increment the various observation counters
			$observer_data{$observer_code}->{observation_count}++;
			$daily_solar_observation_count{$julian_date}++;
			$total_observation_count++;
			$daily_observer_count{$julian_date}->{$observer_code} = 0;

			my $group_number = $solar_data_record->{group_number};
			my $sunspot_number = $solar_data_record->{sunspot_number};
			my $k_factor = $observer_data{$observer_code}->{k_factor};
			if (!exists($observer_data{$observer_code}->{k_factor}) or !defined($observer_data{$observer_code}->{k_factor})) {
				printf("ERROR - k-factor for observer code '% 4s' not found in observer data - record ignored.\n", $observer_code);
				next;
			}

			my $wolf_number = ($group_number * 10 + $sunspot_number);
			my $wolf_number_squared = $wolf_number * $wolf_number;
			my $adjusted_wolf_number = $wolf_number * $k_factor;
			my $adjusted_wolf_number_squared = $adjusted_wolf_number * $adjusted_wolf_number;
			
			$data_count++;
			$data_sum += $wolf_number;
			$data_sum_squared += $wolf_number * $wolf_number;
			$adjusted_data_sum += $adjusted_wolf_number;
			$adjusted_data_sum_squared += $adjusted_wolf_number * $adjusted_wolf_number;
			
			my $weight = $k_factor == 1 ? 0.1 : 1;
			$weight_sum += $weight;
			$weight_sum_squared += $weight * $weight;
			
			if ($adjusted_wolf_number > 0) {
				$weighted_log_data_count++;
				my $weighted_log_data = $weight * log($adjusted_wolf_number);
				$weighted_log_data_sum += $weighted_log_data;
				$weighted_log_data_sum_squared += $weighted_log_data * $weighted_log_data;
			}
		}
			
		# compute daily values
		if ($data_count > 0) {
			$data_average = $data_sum / $data_count;
			$data_stddev = sqrt($data_sum_squared / $data_count - $data_average * $data_average);
			
			$adjusted_data_average = $adjusted_data_sum / $data_count;
			$adjusted_data_stddev = sqrt($adjusted_data_sum_squared / $data_count - $adjusted_data_average * $adjusted_data_average);
			
			$weight_average = $weight_sum / $data_count;
			$weight_stddev = sqrt($weight_sum_squared / $data_count - $weight_average * $weight_average);
		}
			
		if ($weighted_log_data_count > 0) {
			$weighted_log_data_average = $weighted_log_data_sum / $weighted_log_data_count;
			$weighted_log_data_stddev = sqrt($weighted_log_data_sum_squared / $weighted_log_data_count - $weighted_log_data_average * $weighted_log_data_average);
		}
			
		printf(results_file "% 10d % 10d % 10.2f % 10.2f % 10.2f % 10.2f \n", $julian_date, $daily_solar_observation_count{$julian_date}, $data_average, $data_stddev, $adjusted_data_average, $adjusted_data_stddev);
	}
	#printf(results_file "% 20s \n", scalar(keys(%{$daily_observer_count{$julian_date}})));
	printf(results_file "\n");

	# emit total observation count summary data
	printf(results_file "%30s\n", "----------------------------------------");
	printf(results_file "% 7d observations over this period.\n", $total_observation_count);
	printf(results_file "%30s\n", "----------------------------------------");
	printf(results_file "\n");

	# emit observer count summary data
	printf(results_file "% 10s %30s %20s\n", "----------", "------------------------------", "--------------------");
	printf(results_file "% 10s %30s %20s\n", " observer ", "       full  name             ", "  # of observations ");
	printf(results_file "% 10s %30s %20s\n", "----------", "------------------------------", "--------------------");
	foreach my $observer_code (sort(keys(%observer_data))) {
		printf(results_file "% 10s % 30s % 20d\n", $observer_code, $observer_data{$observer_code}->{name}, $observer_data{$observer_code}->{observation_count});
	}
	printf(results_file "% 10s %30s %20s\n", "----------", "------------------------------", "--------------------");
	printf(results_file "\n");
	
	close(results_file);
# --------------------------------------------------------------------------------------------------------------------
__END__
	sub compute_daily_values {
		my $data_count = shift;
		
		if ($data_count < 1) { return }
		
		$nmoday++;
		$dsqnum = 1. / sqrt($data_count * 1.0);
		$dave[1] /= $data_count;
		$dave[2] /= $dwsum;
		
		if ($nolog == 0) {
			$dave[3] /= $dwsum;
		} else {
			$dave[3] = -1;
		}
		
		if ($data_count > 1) {
			$dsig[1] = ($dsig[1] / $numdat) - ($dave[1]**2);
			$dsig[1] = sqrt(($dsig[1] * $numdat) / ($numdat - 1));
			$dsig[2] = ($dsig[2] / $dwsum) - ($dave[2]**2);
			$dfact = 1. - ($dwsum2 / $dwsum**2);
			$dsig[2] = sqrt($dsig[2] / $dfact);
			
			if ($nolog == 0) {
				$dsig[3] = ($dsig[3] / $dwsum) - $dave[3]**2;
				$dsig[3] = sqrt($dsig[3] * $numdat / ($numdat - 1));
			} else {
				$dsig[3] = -1.;
			}
		} else {
		  @dsig = (0, 0, 0, 0);
		}
		
		if ($nolog == 0) {
			$dave[3] = exp($dave[3]);
			$dsig[3] = exp($dsig[3]);
			$dsig[3] = ($dsig[3] - 1) * $dave[3];
		}
	
		# now start printing the daily summary
		$davep[1] = int($dave[1] + 0.5);
		$davep[2] = int($dave[2] + 0.5);
		$davep[3] = int($dave[3] + 0.5);
	
		printf(results_file "%2i   %4i   %6.1f   %4i   %6.1f\n", 
			$nmoday, $davep[1], $dsqnum * $dsig[1], $davep[2], $dsqnum * $dsig[2]);
	
		$dmave[1] += $dave[1];
		$dmave[2] += $dave[2];
		$dmave[3] += $dave[3];
		$data_count  = 0;
		$dwsum = 0;
		$dwsum2 = 0;
		$nolog = 0;
		@dave = (0, 0, 0, 0);
		@dsig = (0, 0, 0, 0);
		
		return;
	}
# --------------------------------------------------------------------------------------------------------------------