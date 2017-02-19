#!/usr/bin/perl
# process incomming port mod requests
#  generate config scripts
#
#  2/26/2013

use Net::SMTP;

 
 $mail_body = `unix2dos /data/engineering/networking/chk_PMOD/portmod_tkt_script.txt `;
 $mail_body = `cat /data/engineering/networking/chk_PMOD/portmod_tkt_script.txt `;
$mail_to  = 'user@domain';
#$mail_to  = 'ptica1@hotmail.com';

  $subject = "Configuration (PortMod) script";

$smtp = Net::SMTP->new("119.0.0.206");

$smtp->mail($ENV{USER});
    $smtp->to($mail_to);

 
$smtp->data();
$smtp->datasend("MIME-Version: 1.0\n");
$smtp->datasend("Content-Type: text; charset=us-ascii\n");
   $smtp->datasend("From: me\@$ENV{USER}");
    $smtp->datasend("To: $mail_to\n");
    $smtp->datasend("Subject: $subject");


    $smtp->datasend("\n\r");
    $smtp->datasend("$mail_body\n");
    $smtp->dataend();

    $smtp->quit;

print "Mail Sent\n";

