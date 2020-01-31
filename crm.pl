#! /usr/bin/perl 

# Find Chandra flux from ACE or CRM(Kp) data

# Find Chandra "region" for the nearest time in CRM file.
# Output CRM or ACE data, depending on Chandra "region".
# Interpolate CRM proton flux in Kp (linear interpolation of log flux).
# No time interpolation of CRM data - use nearest time tick.

# Robert Cameron
# September 2000
# David Morris
# December 2000: updated to new CRM_p_mn.dat format and year rollover
# RAC, Feb 2001: updated to new CRM data files, for CRM v1.21
# RAC, Jan 2002: include GOES P2 and P5 rates in output
# RAC, Apr 2002: added code to update daily CRM files as needed
# RAC, Sep 2002: added sw_flux*0.5 for magnetosphere, for CRM v2.2
# RAC, Apr 2003: changed from GOES8 to GOES12
# RAC, Nov 2003: replaced ACE EPAM P3 flux data with ACE EPAM FP6p*36
# RAC, Apr 2004: replaced ACE EPAM FP6p*36 flux data with ACE EPAM P3p

use File::Basename qw(dirname);

$t1998 = time - 883612800;
$RE_Float = qr/[+-]?(?:\d+[.]?\d*|[.]\d+)(?:[dDeE][+-]?\d+)?/;

$root_dir = "/data/mta4/proj/rac/ops";
$root_dir_CRM = dirname($0);	# Directory name of executable.  To be changed!

$crmdat_root = "$root_dir_CRM/CRM_p.dat";
$crmnew_root = "$root_dir_CRM/CRM2_p.dat";
$kpdat       = "$root_dir/ACE/kp.dat";
$acedat      = "$root_dir/ACE/fluace.dat";
$ephdat      = "$root_dir/ephem/gephem.dat";
$sumdat      = "$root_dir_CRM/CRMsummary_test.dat";
$arcdat      = "$root_dir_CRM/CRMarchive_test.dat";
$gprodat     = "$root_dir/GOES/proton_flux_channels.txt";
$geprimedat     = "$root_dir/GOES/electron_flux_2_mev.txt";
$g15dat      = "$root_dir/GOES/G15pchan_5m.txt";
$IDL_file    = "$root_dir_CRM/CRM_plots.idl";
$SIM_file    = "$root_dir_CRM/FPHIST-2001.dat";
$OTG_file    = "$root_dir_CRM/GRATHIST-2001.dat";

$delt = 300;

@region = qw(NULL Solar_Wind Magnetosheath Magnetosphere);
@sw_factor = (0,1,2,0.5);
@crm_factor = (0,0,1,1);

# update daily CRM data files as needed, from output of "runcrm"

$size90 = (-s $crmnew_root."90");
if ($size90 && $size90 == (-s $crmnew_root."87")) { 
    @newCRM = <$crmnew_root*>;
    foreach (@newCRM) { ($fn = $_) =~ s/$crmnew_root/$crmdat_root/; rename $_,$fn };
}

# read the GOES-15 data

open GF, $g15dat or print STDERR "$0: Cannot open $g15dat\n";
@gp = <GF>;
die "No GOES-15 data in $g15dat\n" unless (@gp);
@gp = split ' ',$gp[-1];
#$g11p2o = $gp[7];
#if ($#gp == 16) { $g11p2 = $gp[7]*0.011; $g11p5 = $gp[10]*1.41696 };
if ($#gp == 16) { $g15p2 = $gp[7]*3.3; $g15p5 = $gp[10]*12 };

# read the GOES-12 data

open GF, $gprodat or print STDERR "$0: Cannot open $gprodat\n";
@gp = <GF>;
die "No GOES-primary data in $gprodat\n" unless (@gp);
@gp = split ' ',$gp[-1];
#$g13p2o = $gp[7];
#if ($#gp == 16) { $g13p2 = $gp[7]*0.011; $g13p5 = $gp[10]*1.41696 };
if ($#gp == 13) { $gprimaryp4 = $gp[5]*3.3; $gprimaryp7 = $gp[8]*12 };
#print $#gp;
#print $gp[5]."$_\n";
#print $gp[8]."$_\n";


open GF, $geprimedat or print STDERR "$0: Cannot open $geprimedat\n";
@gp = <GF>;
die "No GOES-Primary data in $geprimedat\n" unless (@gp);
@gp = split ' ',$gp[-1];
$gelectron2 = $gp[1];
#print $gelectron2."$_\n";
# read the Chandra ephemeris data

open EF, $ephdat or die "$0: Cannot open $ephdat\n";
@eph = split ' ',<EF>;
$alt = $eph[0];
$leg = $eph[1];

# read the Kp data

$kp = -1.0;
$kpi = '00';
for my $kp_file ($kpdat, "$kpdat.good") {
    open(KF, $kp_file) or next;
    while (<KF>) { @kp = split };
    close KF;
####    if (defined $kp[-3] and $kp[-3] =~ /$RE_Float/) {   #--- Nov 04, 2015 (ace data format change???)
####	$kp = ($kp[-3] >= 0)? $kp[-3] : $kp[-1];
    if (defined $kp[-2] and $kp[-2] =~ /$RE_Float/) {
   	    $kp = ($kp[-2] >= 0)? $kp[-2] : $kp[-1];
	    $kpi = sprintf "%3.1f",$kp;
	    $kpi =~ s/\.//;
# Keep a copy of last good k_p file
	    system("cp $kpdat $kpdat.good") if $kp_file eq $kpdat;
	    last;
    }
}

# read the ACE data

$ace = 0;
for my $ace_file ($acedat, "$acedat.good") {
    open(AF, $ace_file) or next;
    @ff = <AF>;
    close AF;
    if (defined $ff[-3]) {
	my @ace = split ' ',$ff[-3];
	next unless defined ($ace = $ace[11]);
	system("cp $acedat $acedat.good") if $ace_file eq $acedat;
	last;
    }
}

# read the Chandra CRM fluence summary data file

open FF, $sumdat or die "$0: Cannot open $sumdat\n";
while (<FF>) { 
    @f = split;
    push @sum, $f[-1];
}
close FF;

# read CRM model data
# and combine CRM and ACE fluxes according to CRM region

$crmdat = $crmdat_root.$kpi;
open CF, $crmdat or die "$0: Cannot open $crmdat\n";
$crm2 = <CF>;
while (<CF>) {
    @crm1 = split;
    last if ($crm1[0] > $t1998);
    $crm2 = $_;
}
@crm2 = split ' ',$crm2;
@crm = (abs($crm1[0]-$t1998) < abs($crm2[0]-$t1998))? @crm1 : @crm2;
$region = $crm[1];
$flux = $crm_factor[$region]*$crm[2] + $sw_factor[$region]*$ace;

# get the current month and day of year

($sec,$min,$hour,$dum,$dum,$year,$dum,$yday,$dum) = gmtime();

$year += 1900;
$yday++;
$ydoy = $year*1000.0 + $yday + $hour/24 + $min/1440 + $sec/86400;

# read the SIM file

open(SIMF,$SIM_file) or die "$0: Cannot open $SIM_file\n";
while (<SIMF>) {
    @cols = split;
    @date = split /:/, $cols[0];
    $ydate = $date[0]*1000.0 + $date[1] + $date[2]/24 + $date[3]/1440 + $date[4]/86400;
    last if ($ydate > $ydoy);
    $si = $cols[1];
}

# read the OTG file

open(OTGF,$OTG_file) or die "$0: Cannot open $OTG_file\n";
while (<OTGF>) {
    @cols = split;
    @date = split /:/, $cols[0];
    $ydate = $date[0]*1000.0 + $date[1] + $date[2]/24 + $date[3]/1440 + $date[4]/86400;
    last if ($ydate > $ydoy);
    $hetg = $cols[1];
    $letg = $cols[2];
}

$otg = "NONE";
$otg = "HETG" if ($hetg =~ /IN/  && $letg =~ /OUT/);
$otg = "LETG" if ($hetg =~ /OUT/ && $letg =~ /IN/ );
$otg = "BAD"  if ($hetg =~ /IN/  && $letg =~ /IN/ );

# attenuate flux according to SIM and OTG positions

$aflux = $flux;
$aflux *= 0.0 if ($si =~ /HRC/);
$aflux *= 0.5 if ($otg =~ /LETG/);
$aflux *= 0.2 if ($otg =~ /HETG/);

# This whole section is dependent on position in summary file so need to update every time file changes
$gprimaryp4 = $sum[-13] unless ($gprimaryp4);
#$g15p2 = $sum[-11] unless ($g15p2); #bring back if secondary goes returns
$gprimaryp7 = $sum[-12] unless ($gprimaryp7);
#$g15p5 = $sum[-9] unless ($g15p5);
$ostart = $sum[-10];
$fluence = $sum[-5];
$afluence = $sum[-4];

# archive and re-initialize for a new orbit

if ($leg eq "A" and $sum[-6] eq "D") {
    $oend = sprintf "%4.4d:%3.3d:%2.2d:%2.2d:%2.2d",$year,$yday,$hour,$min,$sec;
    open ARCF, ">>$arcdat" or die "Cannot open $arcdat\n";
    print ARCF "$ostart   $oend    $fluence    $afluence\n";
    $ostart = $oend;
    $fluence = 0;
    $afluence = 0;
}

$fluence += ($flux * $delt);
$afluence += ($aflux * $delt);

$txt  = "                    Currently scheduled FPSI, OTG : $si $otg\n";
$txt .= "                                     Estimated Kp : $kp\n";
$txt .= sprintf "        ACE EPAM P3 Proton Flux (p/cm^2-s-sr-MeV) : %.2e\n",$ace;
$txt .= sprintf "            GOES-R P4 flux, in RADMON P4GM  units : %.2f\n",$gprimaryp4;
$txt .= sprintf "            GOES-R P7 flux, in RADMON P41GM units : %.2f\n",$gprimaryp7;
$txt .= sprintf "            GOES-R E > 2.0 MeV flux (p/cm^2-s-sr) : %.1f\n",$gelectron2;
$txt .= "                                 Orbit Start Time : $ostart\n";
$txt .= "              Geocentric Distance (km), Orbit Leg : $alt $leg\n";
$txt .= "                                       CRM Region : $region ($region[$region])\n";
$txt .= sprintf "           External Proton Flux (p/cm^2-s-sr-MeV) : %.4e\n",$flux;
$txt .= sprintf "         Attenuated Proton Flux (p/cm^2-s-sr-MeV) : %.4e\n",$aflux;
$txt .= sprintf "  External Proton Orbital Fluence (p/cm^2-sr-MeV) : %.4e\n",$fluence;
$txt .= sprintf "Attenuated Proton Orbital Fluence (p/cm^2-sr-MeV) : %.4e\n",$afluence;
$txt .= sprintf "\n";
$txt .= sprintf "Due to transition to GOES-R, what used to be P2 is now P4 and what used to be P5 is not P7\n";
$txt .= sprintf "This message will dissappear in 01/31/2020\n";

open OF, ">$sumdat" or die "$0: Cannot open $sumdat\n";
print OF $txt;
close OF;

# make the CRM radiation prediction plots
# --- following is disabled (lost sub programs)
`/usr/local/bin/idl $IDL_file > /dev/null 2>&1`;
