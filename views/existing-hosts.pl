 use File::Find;
 
 print "<select name=\"file\">";
  find sub {print "<option>". $File::Find::name . "</option>\n"}, $config{'conf_dir'}."/".$config{'sites_available_dir'}.".conf";
  print "</select>";
print &ui_form_start("allmanual_save.cgi", "form-data");
$data = &read_file_contents($config{'conf_dir'} . "/nginx.conf");
print &ui_textarea("data", $data, 20, 80, undef, undef,
		   "style='width:100%'"),"<br>\n";
