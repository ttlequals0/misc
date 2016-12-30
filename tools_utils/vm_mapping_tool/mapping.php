<html>
 <head>
  <title>VM Mapping Tool</title>
  <link rel="stylesheet" type="text/css" href="style.css">
  <link rel="stylesheet" href="http://code.jquery.com/mobile/1.4.5/jquery.mobile-1.4.5.min.css"> 
  <script src="http://code.jquery.com/jquery-1.11.3.min.js"></script>
  <script src="http://code.jquery.com/mobile/1.4.5/jquery.mobile-1.4.5.min.js"></script>
  <script src="sorttable.js"></script>
  <script src="table.js"></script>

</head>
 <body>
  <div id="title">
	<h1>VM Mapping Tool</h1>
	<h2>Purpose, to show whch host a VM resides on. Information is updated once an hour.</h2>
 </div> 
<?php	function readcsv($filename, $header=false, $id) {
	$handle = fopen($filename, "r");
	echo "<table class=i\"sortable\" id=\"$id\">";
	//display header row if true
	if ($header) {
    		$csvcontents = fgetcsv($handle);
    		echo '<tr>';
    	foreach ($csvcontents as $headercolumn) {
        	echo "<th>$headercolumn</th>";
    		}
    	echo '</tr>';
	}	
	// displaying contents
	while ($csvcontents = fgetcsv($handle)) {
    		echo '<tr>';
    	foreach ($csvcontents as $column) {
        	echo "<td>$column</td>";
    	}
    	echo '</tr>';
	}
	echo '</table>';
	fclose($handle);
	}
?>

<div data-role="main" class="ui-content">
    <div data-role="collapsible" data-collapsed="true">
      <h2>Prod TT Platform</h2>
      <input type="text" id="searchTerm0" class="search_box" placeholder="Enter text to search..." onkeyup="doSearch('dataTable0', 'searchTerm0')" />
      <?php readcsv('prod_debesys.csv',true,'dataTable0'); ?>
    </div>
</div>
<div data-role="main" class="ui-content">
    <div data-role="collapsible" data-collapsed="true">
      <h2>Prod 7x</h2>
      <input type="text" id="searchTerm1" class="search_box" placeholder="Enter text to search..." onkeyup="doSearch('dataTable1', 'searchTerm1')" />
      <?php readcsv('prod_ttnet.csv',true,'dataTable1'); ?>
    </div>
</div>
<!--<div data-role="main" class="ui-content">
    <div data-role="collapsible" data-collapsed="true">
      <h2>Mock Debesys</h2>
      <input type="text" id="searchTerm2" class="search_box" placeholder="Enter text to search..."  onkeyup="doSearch('dataTable2', 'searchTerm2')" />
      <?php /* readcsv('mock_debesys.csv',true,'dataTable2'); */ ?>
    </div>
</div>
</div>-->
 </body>
</html>
