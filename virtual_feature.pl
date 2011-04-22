do 'virtualmin-nginx-lib.pl';

use File::Copy;
use Data::Dumper;
use Date::Parse;

our ($conf_dir, $sites_avaliable_dir, $sites_enabled_dir, $log_dir);

#TODO if $conf_dir, $sites_avaliable_dir, $sites_enabled_dir come from user put trail slash
#TODO Config set by user not working, only default values

if($config{'conf_dir'} eq "")
{
  $conf_dir = '/etc/nginx/';
}

if($config{'sites_available_dir'} eq "")
{
  $sites_available_dir = 'sites-available/';
}

if($config{'sites_enabled_dir'} eq "")
{
  $sites_enabled_dir = 'sites-enabled/';
}



sub feature_always_links
{
  
}

sub feature_backup
{
  
}

sub feature_bandwidth
{
  my ($d, $start, $bwhash) = @_;

  $conffile="$conf_dir$sites_available_dir$d->{'dom'}.conf";
  
  open(FILE,$conffile);

  while($line=<FILE>) {
    if($line =~ /^[^#]*access_log\s([^;]+)[\s;]/) {
      $file = $1;
      break;
    }
  }
  if(!$file) { print STDERR "nginx: can't find log file for domain $d->{'dom'}"; }
  open(LOG,$file);

  while($line=<LOG>) {
    @line_spl = split(/ /,$line);
  
    $line =~ m/\[([^\]]+)\]/;
    $date = $1;
  
    $time=str2time($date);
  
    $bwtime = int($time/86400);
    
    $line =~ m/(\d+) "[\d\.\-]+"/;
    $in = $1;
    
    $out = $line_spl[10];
    if($time>$start) {
      $bwhash->{'web_'.$bwtime} += ($in+$out);
      $bwhash->{'nginx_'.$bwtime} += ($in+$out);
    }
  }

  return $time;
}

sub feature_check
{
  my $conf_file = $conf_dir . "nginx.conf";
  
  unless(-r $conf_file)
  {
    return "Nginx needs to be installed.";
  }
  
  unless (-d $conf_dir . $sites_available_dir)
  {
    mkdir($conf_dir . $sites_available_dir);
  }
  
  unless (-d $conf_dir . $sites_enabled_dir)
  {
    mkdir($conf_dir . $sites_enabled_dir);
  }

  
  open(CONF, $conf_file);
  
  local $/ = undef;
  my $filestring = <CONF>;
  close(CONF);
  
  #TODO: check if include directive not comment "# include /etc/nginx/sites-enabled/*;"
  my $pattern = "include " . $conf_dir . $sites_enabled_dir . "\\*;";
  
  unless ($filestring =~ /$pattern/) 
  {
    
    chop($filestring);
    
    $filestring .= "\tinclude " . $conf_dir . $sites_enabled_dir . "*;\n}"; 
    
    open(CONF,  ">", $conf_file);
    
    print(CONF $filestring);
    
    close(CONF);
    
  }
    
  return undef;
  
}

sub feature_clash
{
  return undef;
}

sub feature_delete
{
  if($d->{'alias'}>0) 
  {
    &$virtual_server::first_print("Nginx alias mode - nothing to do");
    
    &$virtual_server::second_print(".. done");
    
    return;
  }
  
  my ($d) = @_;
  &$virtual_server::first_print("Deleting Nginx site ..");
  
  unlink($conf_dir . $sites_enabled_dir . $d->{'dom'} . ".conf");
  unlink($conf_dir . $sites_available_dir . $d->{'dom'} . ".conf");
  
  reload_nginx();
  
  &$virtual_server::second_print(".. done");
  
}

sub feature_depends
{
  return undef;
}

sub feature_disable
{
  my ($d) = @_;
  &$virtual_server::first_print("Disabling Nginx website ..");
  unlink($conf_dir . $sites_enabled_dir . $d->{'dom'} . ".conf");
  reload_nginx();
  &$virtual_server::second_print(".. done");
}

sub feature_disname
{
  return "Nginx website";
}

sub feature_enable
{
  
  my ($d) = @_;
  &$virtual_server::first_print("Re-enabling Nginx website ..");
  symlink($conf_dir . $sites_available_dir . $d->{'dom'} . ".conf", $conf_dir . $sites_enabled_dir . $d->{'dom'} . ".conf");
  reload_nginx();
  &$virtual_server::second_print(".. done");
  
  
}

sub feature_import
{
  
}

sub feature_label
{
  return "Setup Nginx website for domain?";
}

sub feature_links
{
  
}

sub feature_losing
{
  return "The Nginx config file for this website will be deleted.";
}

sub feature_modify
{
  
  &$virtual_server::first_print("modifying Nginx site ..");
  my ($d, $oldd) = @_;
  
  if ($d->{'dom'} ne $oldd->{'dom'} || $d->{'home'} ne $oldd->{'home'}) {
  
    if($config{'log_dir'} eq "")
    {
      $log_dir = "$d->{'home'}/logs/";
      $old_log_dir = "$oldd->{'home'}/logs/";
    }
    &$virtual_server::first_print("renaming files from $oldd->{'dom'} to $d->{'dom'}");
    
    open(CONFFILE, "<" . $conf_dir . $sites_available_dir . $oldd->{'dom'} . ".conf");
    @conf=<CONFFILE>;
    close(CONFFILE);
  
    $conf=join("",@conf);
  
    $conf =~ s/(server_name.*\s)$oldd->{'dom'}/$1$d->{'dom'}/gi;
    $conf =~ s/(server_name.*\s)www\.$oldd->{'dom'}/$1www.$d->{'dom'}/gi;

    $conf =~ s/(access_log\s+)$old_log_dir$oldd->{'dom'}\.access\.log/$1$log_dir$d->{'dom'}\.access\.log/gi;
    $conf =~ s/(error_log\s+)$old_log_dir$oldd->{'dom'}\.error\.log/$1$log_dir$d->{'dom'}\.error\.log/gi;
    
    open(CONFFILE, ">" . $conf_dir . $sites_available_dir . $oldd->{'dom'} . ".conf");
    print(CONFFILE $conf);
    close(CONFFILE);
    
    unlink($conf_dir . $sites_enabled_dir . $oldd->{'dom'} . ".conf");
    rename($conf_dir . $sites_available_dir . $oldd->{'dom'} . ".conf", $conf_dir . $sites_available_dir . $d->{'dom'} . ".conf");
    symlink($conf_dir . $sites_available_dir . $d->{'dom'} . ".conf", $conf_dir . $sites_enabled_dir . $d->{'dom'} . ".conf");
  
    reload_nginx();
  }
  
  &$virtual_server::second_print(".. done");
}

sub feature_name
{
  return "Nginx website";
}

sub feature_restore
{
  
}

sub feature_setup
{
  my ($d) = @_;
  &$virtual_server::first_print("Setting up Nginx site ..");
  
  my $file;
  
  if($config{'log_dir'} eq "")
  {
    $log_dir = "$d->{'home'}/logs/";
  }
  
  if($d->{'alias'}>0) 
  {
    &$virtual_server::first_print("feature_setup - Nginx alias mode - exiting");
    
    return;
  }
  
  
  open($file, ">" . $conf_dir . $sites_available_dir . $d->{'dom'} . ".conf");
  #TODO in config.info add nginx config template with default value conf_tmpl=nginx config template,9,server{ listen $d->{'ip'}:80;} or get it from nginx_conf.tpl and parse
  #TODO Determine subdomain and dont put rewrite ^/(.*) http://www.$d->{'dom'} permanent;

  if($config{'nginx_conf_tpl'} eq "") {
    open(CONFFILE, "<" . "/usr/share/webmin/nginx-webmin/nginx-default.conf");

    @conf=<CONFFILE>;
    close(CONFFILE);
    $conf=join("",@conf);
  } else {
    $conf=$config{'nginx_conf_tpl'};
  }

  $conf_v_nginx_ip = $config{'nginx_ip'} ? $config{'nginx_ip'} : $d->{'ip'};
  $conf_v_nginx_port = $config{'nginx_port'} ? $config{'nginx_port'} : '80';
  $conf_v_proxy_ip = $config{'proxy_ip'} ? $config{'proxy_ip'} : '127.0.0.1';
  $conf_v_proxy_port = $config{'proxy_port'} ? $config{'proxy_port'} : '81';

  $conf =~ s/\t/\n/g;

  $conf =~ s/\$\{DOM\}/$d->{'dom'}/g;
  $conf =~ s/\$\{IP\}/$conf_v_nginx_ip/g;
  $conf =~ s/\$\{PORT\}/$conf_v_nginx_port/g;
  $conf =~ s/\$\{PROXY_IP\}/$conf_v_proxy_ip/g;
  $conf =~ s/\$\{PROXY_PORT\}/$conf_v_proxy_port/g;
  $conf =~ s/\$\{HOME\}/$d->{'home'}/g;
  
  print($file $conf);
  
  close $file;
  
  symlink($conf_dir . $sites_available_dir . $d->{'dom'} . ".conf", $conf_dir . $sites_enabled_dir . $d->{'dom'} . ".conf");
  
  reload_nginx();
  
  &$virtual_server::second_print(".. done");
}

# feature_setup_alias(&domain, &alias)
# Called when an alias of this domain is created, to perform any required
# configuration changes. Only useful when the plugin itself does not implement
# an alias feature.
sub feature_setup_alias
{
  local ($d, $alias) = @_;
  &$virtual_server::first_print("Setting up Nginx alias site ..");
  
  open(CONFFILE, "<" . $conf_dir . $sites_available_dir . $d->{'dom'} . ".conf");
  @conf=<CONFFILE>;
  close(CONFFILE);
  
  $conf=join("",@conf);
  
  $conf =~ s/(server_name\s.*$d->{'dom'} www\.$d->{'dom'})/$1 $alias->{'dom'} www\.$alias->{'dom'}/gi;

  open(CONFFILE, ">" . $conf_dir . $sites_available_dir . $d->{'dom'} . ".conf");
  print(CONFFILE $conf);
  close(CONFFILE);
  
  reload_nginx();
  
  &$virtual_server::second_print(".. done");
}

# feature_delete_alias(&domain, &alias)
# Called when an alias of this domain is deleted, to perform any required
# configuration changes. Only useful when the plugin itself does not implement
# an alias feature.
sub feature_delete_alias
{
  local ($d, $alias) = @_;
  &$virtual_server::first_print("Deleting Nginx alias site ..");

  open(CONFFILE, "<" . $conf_dir . $sites_available_dir . $d->{'dom'} . ".conf");
  @conf=<CONFFILE>;
  close(CONFFILE);
  
  $conf=join("",@conf);
  
  $conf =~ s/(server_name\s.*)$alias->{'dom'}/$1/gi;
  $conf =~ s/(server_name\s.*)www\.$alias->{'dom'}/$1/gi;

  open(CONFFILE, ">" . $conf_dir . $sites_available_dir . $d->{'dom'} . ".conf");
  print(CONFFILE $conf);
  close(CONFFILE);
  
  reload_nginx();
  
  &$virtual_server::second_print(".. done");


}

# feature_modify_alias(&domain, &alias, &old-alias)
# Called when an alias of this domain is deleted, to perform any required
# configuration changes. Only useful when the plugin itself does not implement
# an alias feature.
sub feature_modify_alias
{
  &$virtual_server::first_print("Modifying Nginx alias site ..");
}


sub feature_suitable
{
  return 1;
}

sub feature_validate
{
  return undef;
}

sub feature_webmin
{
  
}

sub reload_nginx
{
  if($config{'nginx_pid'} eq "")
  {
    $nginx_pid = '/var/run/nginx.pid';
  }
  #TODO test nginx conf = nginx -t
  my $pid = `cat $nginx_pid`;
  `kill -HUP $pid`;
}

sub fix_perm
{
    # TODO nginx run as www-data, default perm on public_html in Virtualmin 0740 Sequrity alert if chmod 0755
    my ($dir) = @_;
    
    if($config{'public_html_perm'} eq "")
    {
        $public_html_perm = '0755';
    }
    chmod oct($public_html_perm), $dir;
}