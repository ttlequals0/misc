#!/usr/bin/perl

use warnings;
use strict;
use Net::SSH::Expect;
use Net::Telnet::Cisco;




        my @Telnet;
        $key ="119.1.9.148";
                open(LOG,">/tmp.tmp") or die "Can't open file for writing: $!";

                my $ssh= Net::SSH::Expect->new(
                        host => $key,
                        password => 'en1gma31',
                        user => 'runscript2',
                        raw_pty => 1,
                        timeout => 5
                );

                my $login_output = $ssh->login();
                if($login_output =~ /refused/)
                {

                        print $login_output;
                        push(@Telnet, $key);


                }



                $ssh->exec("term length 0");

                print LOG "Output of show except: \n";
                print LOG my @Except = $ssh->exec("sh ip bgp sum");

                print LOG "\n\n";

                print LOG "Output of show service: \n";
                print LOG my @Service = $ssh->exec("sh access-list");


                #print LOG "Output of show log: \n\n";
                #print LOG my @Log = $ssh->exec("sh log");


                #print LOG "Output of show interface: \n\n";
                #print LOG my @Int = $ssh->exec("sh interface");


                #print LOG my @Count = $ssh->send("clear count\r");


                $ssh->send("exit");

                $ssh->close();
        #_TELNET(\@Telnet);
#       print \@Telnet;
close(LOG);

sub _TELNET
{
        my @Telnet = @{$_[0]};
        foreach my $host (@Telnet)
        {
                my $telnet = Net::Telnet::Cisco->new(host => "$host");
                $telnet->login('user','pass');
                print $host;
        }


