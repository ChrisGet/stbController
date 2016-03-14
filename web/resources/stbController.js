<!-- hide script from old browsers
var isFirefox = typeof InstallTrigger !== 'undefined';

window.onload = function () {	// Run these functions when the page first loads
	dateTime();
	announcements();
	dynamicTitle('get');

	// Bind the tooltip function
        $(document).ready(function() {
                // Tooltip only Text
                $('body').on({
                        mouseenter: function(){
                                // Hover over code
                                var title = $(this).attr('value');
                                $('<p class="tooltip"></p>').text(title).appendTo('body').fadeIn('fast');
                        },
                        mouseleave: function() {
                                // Hover out code
                                $('.tooltip').remove();
                        },
                        mousemove: function(e) {
                                var mousex = e.pageX + 20; //Get X coordinates
                                var mousey = e.pageY + 10; //Get Y coordinates
                                $('.tooltip').css({ top: mousey, left: mousex })
                        }
                }, '.masterTooltip');
        });
}

window.onunload = window.onbeforeunload = function ()  {	// Run the logLastBoxes function when the page is unloaded (Refreshed or tab is navigated to elsewhere
	logLastBoxes();
}

//$.ajaxSetup({ cache: false });

var stbHash = {};	// Create the GLOBAL stbHash object (hash) to handle selected STBs from the grid
var lastRow;		// Create the GLOBAL lastRow variable (scalar) to record last selected row
var lastRowHL;		// Create the GLOBAL lastRowHL variable (scalar) to record last highlighted row

function dateTime() {	// This function handles the updating of the real time server clock on the main page
	var xmlhttp;
	if (window.XMLHttpRequest) {// code for IE7+, Firefox, Chrome, Opera, Safari
		xmlhttp=new XMLHttpRequest();
	} else {// code for IE6, IE5
		xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
	}
        xmlhttp.open("GET","cgi-bin/scripts/showTime.pl", true);
	xmlhttp.onreadystatechange=function(){
        	if (xmlhttp.readyState==4) {
		        var returned = xmlhttp.responseText;
			var bits = returned.split(',');
		        var date = new Date();
			var dayname = bits[0];
		        var dayno = bits[1];
		        var month = bits[2];
		        month = parseInt(month, 10);
		        month--;
		        var year = bits[3];
		        var hours = bits[4];
		        var mins = bits[5];
		        var secs = bits[6];
			date.setFullYear(year);
		        date.setMonth(month);
		        date.setDate(dayno);
		        date.setHours(hours);
		        date.setMinutes(mins);
		        date.setSeconds(secs);

		        var updateTime = setInterval(function() {	// Var updateTime holds the ID for this interval function. This can be cleared later
		                var div = document.getElementById('dateTimeDiv');
		                if (div) {
		                        secs++;
        		                if (secs == 60) {
                		                secs = 0;
						mins++;
						announcements(); // Update the announcements div with latest scheduled events info
		                        }
        		                if (mins == 60) {	// Each hour we restart the function to get the time from the server again
                		                clearInterval(updateTime);	// Clear the interval for updateTime so it stops
                        		        dateTime();	// Start the dateTime function again
                                		return;		// Return from this instance of the function
		                        }
        		                date.setHours(hours);
                		        date.setMinutes(mins);
                        		date.setSeconds(secs);
					var formatteddate = date.toString().replace(',',''); // Change the date format to a standard string while removing all ',' characters
        		                var parts = formatteddate.split(" ");
                		        var datebit = parts[0] + " " + parts[1] + " " + parts[2] + " " + parts[3];
                        		var timebit = parts[4];
	                        	var datestring = timebit + ' - ' + datebit;
	        	                $('#dateTimeDiv').html(datestring);	// Update the html in div 'dateTimeDiv' with the new date info
        	        	}
	        	},1000);
		}
	}
        xmlhttp.send(null);

}
// ############### End of dateTime function

function announcements() {	// This function handles the server announcements section on the main page. It is only used for scheduled events info
	var div = document.getElementById('messages');
	if (div) {
		var xmlhttp;
		if (window.XMLHttpRequest) {// code for IE7+, Firefox, Chrome, Opera, Safari
			xmlhttp=new XMLHttpRequest();
		} else {// code for IE6, IE5
			xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
		}
	        xmlhttp.open("GET","cgi-bin/scripts/messages.pl", true);
		xmlhttp.onreadystatechange=function(){
	                if (xmlhttp.readyState==4) {
			        var returned = xmlhttp.responseText;
				$('#messages').html(returned);
			}
		}
	        xmlhttp.send();
	}
	return;
}
// ############### End of announcements function

function dynamicTitle($option) {	// This function handles the editing of the Title of the main page
	if ($option == 'get') {
		var xmlhttp;
		if (window.XMLHttpRequest) {// code for IE7+, Firefox, Chrome, Opera, Safari
  			xmlhttp=new XMLHttpRequest();
  		} else {// code for IE6, IE5
			xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
		}

        	var date = Date();
	        xmlhttp.open("GET","web/dynamicTitle.txt?"+date, true);
		xmlhttp.onreadystatechange=function(){
   	        	if (xmlhttp.readyState==4) {
				var title = xmlhttp.responseText;

				if (!title) {
					$('#dynamicTitle').text('Click here to change the default title!');
				} else {
					var blankregex = /\S+/;
                        		var notblank = blankregex.exec(title);
					if (!notblank) {
						$('#dynamicTitle').text('Click here to change the default title!');
					} else {
						if (title.match(/404 not found/i)) {
							$('#dynamicTitle').text('Click here to change the default title!');
						} else {
							$('#dynamicTitle').text(title);
						}
					}
				}
			}
		}	
	        xmlhttp.send(null);
	}

	if ($option == 'set') {
		var current = $('#dynamicTitle').text();
		var newtitle = prompt("Please enter your new page title",current);
		if (!newtitle) {
			return;
		} else {
			if (newtitle == current) {
				return;
			}
			var blankregex = /\S+/;
			var notblank = blankregex.exec(newtitle);
			if (!notblank) {
				var conf = confirm('Your new page title is blank. If you select ok, the page title will be returned to the default. Do you want to proceed?');
				if (conf == false) {
					return;
				}
			}
			alert('Your page title has been updated. The page will now be reloaded.');
			perlCall('','scripts/editPageTitle.pl','title',newtitle);
			setTimeout(function(){location.reload()},1000);
		}
	}
}
// ############### End of dynamicTitle function

function stbControl($action,$commands) {	// This function handles the control of STBs from the STB Grid
	var comstring = '';
	for (var key in stbHash) {
		comstring += key + ',';
	}

	var comstring2 = comstring.replace(/,$/,''); // Remove any trailing commas from comstring

	// Validate whether any STBs have been selected for control. Return if none have
	if (!comstring2) {
		alert('No valid STBs have been selected for control');
		return;
	}

	perlCall('','scripts/stbControl.pl','action',$action,'command',$commands,'info',comstring2);
}
// ############### End of stbControl function

function perlCall ($element, $script, $param1, $value1, $param2, $value2, $param3, $value3, $param4, $value4) {	// This function allows running of any script from within this javascript
	var regex = /\S+/;
	var elemmatch = regex.exec($element);
	var xmlhttp;
	if (window.XMLHttpRequest){
		xmlhttp=new XMLHttpRequest();
	} else {
		xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
	}

	xmlhttp.open("GET","cgi-bin/" + $script +"?"+$param1 + "=" + $value1 + "&"+$param2+"="+$value2 + "&"+$param3+"="+$value3 + "&"+$param4+"="+$value4,true);
	xmlhttp.onreadystatechange=function(){
		if (xmlhttp.readyState==4) {
			if (elemmatch) {	// If a html element has been defined in $element, put the script output in to that element
				document.getElementById($element).innerHTML=xmlhttp.responseText;
			}
		}
	}
	xmlhttp.send(null);

	// Reset the sequenceIndex to 1
	sequenceIndex = '1';
}
// ############### End of perlCall function

function pageCall ($element, $page) {	// This function allows calling of html pages
	var xmlhttp;
        if (window.XMLHttpRequest){                                                
                xmlhttp=new XMLHttpRequest();
        } else {                    
                xmlhttp=new ActiveXObject("Microsoft.XMLHTTP"); 
        }

	xmlhttp.open("GET",$page);
        xmlhttp.onreadystatechange=function(){
                if (xmlhttp.readyState==4) {
                        document.getElementById($element).innerHTML=xmlhttp.responseText;
                }
        }
	xmlhttp.send();
}
// ############### End of pageCall function

function getLastBoxes() {	// This function gets the list of last STBs selected in the grid and sets them to selected in the STB grid. It uses the client browsers localStorage ability
	var loaded = document.getElementById('matrixLoaded');
	if (!loaded) {
		window.setTimeout(getLastBoxes, 100);
	} else {
		if (localStorage && 'lastBoxes' in localStorage) {
			var boxstring = localStorage.lastBoxes;
			var boxes = boxstring.split(",");
			var arrayLength = boxes.length;
			stbHash = {};
			for (var i=0;i<arrayLength;i++) {
				var stb = boxes[i];
				colorToggle(stb,'selected');
			}		
		}
	}
}
// ############### End of getLastBoxes function

function logLastBoxes() {	// This function logs the last selected STBs from the STB grid. It uses the client browsers localStorage ability
	var comstring = '';
        for (var key in stbHash) {
                comstring += key + ',';
        }
	localStorage && (localStorage.lastBoxes = comstring);
}
// ############### End of logLastBoxes function

function validate() {	// This function validates and submits the data given when setting up the STB grid for the first time
	var x = document.forms["createGridConfig"]["columns"].value;
	var y = document.forms["createGridConfig"]["rows"].value;
	var text = /[a-zA-Z]+/;
	var matchx = text.exec(x);
	var matchy = text.exec(y);

	if (x == null || x == "" || (matchx)) {
        	alert("Invalid Columns selection, please enter the number of columns you require (Numbers only)");
		document.forms["createGridConfig"]["columns"].value = "";
		return false;
	} 
	if (y == null || y == "" || (matchy)) {
	        alert("Invalid Rows selection, please enter the number of rows you require (Numbers only)");
		document.forms["createGridConfig"]["rows"].value = "";
		return false;   
	} 

	$(document).ready(function() {
		$.ajax( { 
			type: "POST",
			url: 'cgi-bin/scripts/pages/forms/createGridConfig.cgi', 
			data: $('#createGridConfig').serialize(),
		});
	});
	alert('Congratulations! Your new grid has been created');
	document.getElementById('dynamicPage').innerHTML = '<p style="font-size:30px;">Loading The New Grid, Please Wait ...</p>';
	setTimeout(function(){perlCall('dynamicPage','scripts/pages/stbGrid.pl')},3000);
	//return false;
}
// ############### End of validate function

function editSTBData($name) {	// This function handles editing details of an STB in the "STB Data" page
	var name = $('#name').val();
	var blanknameregex = /\S+/;	// Non whitespace, 1 or more of.
	var unconfregex = /^\s*\-\s*$/;
	var matchblank = blanknameregex.exec(name);
	var matchunconf = unconfregex.exec(name);

	if (!name || !matchblank || matchunconf) {
		var conf = confirm('Giving this STB a name of "-", or no name at all, will mark it as unconfigured. Are you sure you want to do this?');
		if (conf == false) {
			return;
		}
	}

	var spacerregex = /^\s*\:\s*$/;
	var matchspacer = spacerregex.exec(name);
	if (matchspacer) {
		var conf = confirm('Giving this STB a name of ":" will mark it as a grid spacer and it will have no control functionality. Are you sure you want to do this?');
		if (conf == false) {
			return;
		}
	}

	///////	IP Address and Port input field validation
	var inputs = document.editSTBConfigForm.getElementsByTagName("input");	// Get all "input" elements from the STB Data form
	for (var i=0;i<inputs.length;i++) {
		var val = inputs[i].value;
		if (!val || !val.match(/\S+/)) {	// If the field is undefined or only contains whitespace, ignore it
			continue;
		}

		var inputid = inputs[i].id;
		var regex = /.*ip(.*)/i;
		var match = regex.exec(inputid);

		if (match) {
			if (match[0]) {
				if (match[1].match(/ort/i)) {	// This will identify an input field that is a port number, not an IP address
					if (val.match(/\D+/)) {	// If 'valid' is true, we have matched a word character in the value for the port. This is invalid so we alert the user
						alert('You have entered non digit characters for a port number. A port can only be digits');
						inputs[i].focus();
						return;
					} else {
						continue;
					}
				} else {
					if (val.match(/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/)) {
						continue;
					} else {
						alert('You have entered an invalid IP address');
						inputs[i].focus();
						return;
					}
				}
			} else {
				if (val.match(/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/)) {
					continue;
				} else {
					alert('You have entered an invalid IP address');
					inputs[i].focus();
					return;
				}
			}
		}

		if (inputid.match(/.*port.*/i)) {
			if (val.match(/\D+/)) {	// If this matches, we have founc a word character in the value for the port. This is invalid so we alert the user
				alert('You have entered non digit characters for a port number. A port can only be digits');
				inputs[i].focus();
				return;
			} else {
				continue;
			}
		}
	}
	///////	End of IP Address and Port input field validation

        $(document).ready(function() {
                $.ajax( {
                        type: "POST",
                        url: 'cgi-bin/scripts/pages/forms/editSTBData.cgi',
                        data: $('#editSTBConfigForm').serialize(),
                });
        });
	alert('Data for STB "' + $name + '" was updated');
	perlCall('dynamicPage','scripts/pages/stbDataPage.pl','option','chooseSTB');
	return false;
}
// ############### End of editSTBData function

function deselect() {	// This function handles the deselect button on the STB grid.
	for (var key in stbHash) {
		colorToggle(key);
	}
	for (var key in highlightedSTBs) {
		document.getElementById(key).className = 'stbButton deselect';
		delete highlightedSTBs[key];
	}
	lastRow = '';
	lastRowHL='';
}
// ############### End of deselect function

function colorToggle($id,$override,$highlight){	// This function handles the STB grid manipulation. It handles which STBs are selected for control, which should be highlighted, and which need video switching to be done
	var item = document.getElementById($id);

	// Return if item is not defined
	if (!item) {
		return;
	}

	// Return if the STB is unconfigured ('-' as its name)
	var text = $('#' + $id).text();
	if (text == '-') {
		return;
	}

	// The code below handles the override call. The override function allows a stb button state to be explicitly set rather than toggled
	if ($override) {
		if ($override == 'selected') {
			item.className = 'stbButton selected';
			stbHash[$id] = 1;
			delete highlightedSTBs[$id];
			perlCall('','scripts/videoSwitching.pl','stbs',$id);	// Once a box is selected, switch to its video too
		}
		if ($override == 'deselect') {
        	        item.className = 'stbButton deselect';
			delete stbHash[$id];
			delete highlightedSTBs[$id];
	        }
		if ($override == 'highlighted') {
        	        item.className = 'stbButton highlighted';
			delete stbHash[$id];
			highlightedSTBs[$id] = '1';		
	        }
		return;
	}

	// The code below will check to see if the user has selected more than one STB in the same column. 
	// The last clicked cell in a column will be selected while the rest will be deselected
	var naym = item.name;
	var myColMatch = /col(\d+)s(tb)/;
	var match = myColMatch.exec(naym);
	var colNo = match[0];
	for (var key in stbHash) {
		if (key == $id) continue;		// If the key and $id are the same, skip to the next iteration
		var thing = document.getElementById(key);
		var matchName = thing.name;
		if(matchName.indexOf(colNo) == 0){
			document.getElementById(key).className = 'stbButton deselect';
	               	delete stbHash[key];
		}
	}

	for (var key in highlightedSTBs) {
		var thing = document.getElementById(key);
                var matchName = thing.name;
                if(matchName.indexOf(colNo) == 0){
                        document.getElementById(key).className = 'stbButton deselect';
                        delete highlightedSTBs[key];
                }
	}

	if (item.className == 'stbButton deselect') {
		item.className = 'stbButton selected';
		stbHash[$id] = 1;
		perlCall('','scripts/videoSwitching.pl','stbs',$id);	// Once a box is selected, switch to its video too
	} else {
		if (item.className == 'stbButton highlighted') {
			item.className = 'stbButton selected';
                	stbHash[$id] = '1';
			delete highlightedSTBs[$id];
		} else {
			item.className = 'stbButton deselect';
			delete stbHash[$id];
		}
	}
}
// ############### End of colorToggle function

var highlightedSTBs = {};	// Create the GLOBAL highlightedSTBs variable (hash)

function rows($row) {	// This function handles the row selection buttons on the STB grid
	var count = document.getElementById($row).cells.length;		// Locate the row by its ID and get the number of cells in it
	var row = document.getElementById($row);			// Save the $row data in var 'row'
	var override;
	var highlight;
	if(lastRowHL == $row) {
		lastRow = $row;
		lastRowHL = '';
		override = 'selected';
		for (var stb in stbHash) {
                	document.getElementById(stb).className = 'stbButton deselect';
              	}
        	stbHash = {};
	} else {
		if(lastRow == $row) {
			override = 'highlighted';
			lastRowHL = $row;
			lastRow = '';
			for (var stb in stbHash) {
                		document.getElementById(stb).className = 'stbButton deselect';
              		}
        		stbHash = {};
		} else {
			lastRow = $row;
			lastRowHL = '';
			override = 'selected';
			for (var stb in highlightedSTBs) {
				document.getElementById(stb).className = 'stbButton deselect';
			}
			highlightedSTBs = {};

			for (var stb in stbHash) {
				document.getElementById(stb).className = 'stbButton deselect';
			}
			stbHash = {};
			
		}
	}

	for(var i=0;i<count;i++) {	// While 'i' is less than the number of cells
		var cell = row.getElementsByTagName("button")[i];	// Locate the button in that cell and save it in 'cell'
		if (!cell) {
			continue;	// Skip the cell if it has no button (STB has been given ':' as its name and is therefore blank)
		}
		var ayedee = cell.id;	// Get the buttons id and save it to 'ayedee'
		var regex = /^Row.*/;
		var match = regex.exec(ayedee);
		if (match) {
			continue;	// Skip the row button that is in that row
		}
		colorToggle(ayedee,override,highlight);	// Send 'ayedee' to the colorToggle function
	}
}
// ############### End of rows function

function arrowDir($opt) {	// This function handles the Row Up and Down buttons on the STB controller
	var lastRow2;
	if (lastRow) {
		lastRow2 = lastRow;
	} else {
		if (lastRowHL) {
			lastRow2 = lastRowHL;
		}
	}

	if (!lastRow2) {
		rows('Row1');
	} else {
		var bits = lastRow2.split("w"); 		// lastRow will be like 'RowX' so we split by 'w' to get the number 
		var num = bits[1];
		var totalrows = document.getElementById('totalRows').value;
		if ($opt == 'INC') {
			if (num == totalrows) {
				rows('Row1');				
			} else {
				num++;
				var newrow = 'Row' + num;
				rows(newrow);
			}
		}
		if ($opt == 'DEC') {
			if (num == '1') {
				var newrow = 'Row' + totalrows;
				rows(newrow);				
			} else {
				num--;
				var newrow = 'Row' + num;
				rows(newrow);
			}
		}
	}
}
// ############### End of arrowDir function

var sequenceIndex = '1';	// Create the GLOBAL sequenceIndex variable (scalar) and set it to '1'

function seqTextUpdate($id,$text,$area) {	// This function handles the first part of adding STBs and Commands in to the dynamic areas on the STB Groups, Sequences, and Events Schedule creation and editing pages
	if (!$area) {
		$area = '';
	}

	var btn = document.createElement("input");
	btn.type = 'button';
	btn.value = $text;
	var newid = $id + '-' + sequenceIndex;
	btn.id = newid
	btn.name = $id; 
	sequenceIndex++;
	var newonclick = "removeFromSeq('" + newid + "','" + $area + "')";
	btn.setAttribute("class", "seqAreaBtn");
	btn.setAttribute("onclick", newonclick);
	insertButtonAtCaret(btn,$area);
}
// ############### End of seqTextUpdate function

function insertButtonAtCaret($btn,$area) {	// This function handles the second part of adding STBs and Commands in to the dynamic areas on the STB Groups, Sequences, and Events Schedule creation and editing pages
	if (!$area) {
		$area = 'sequenceArea';
	}

    	$('#' + $area).focus();
    	var sel, range;
    	if (window.getSelection) {
		// IE9 and non-IE
        	sel = window.getSelection();
        	if (sel.getRangeAt && sel.rangeCount) {
            		range = sel.getRangeAt(0);
            		range.deleteContents();

            		// Range.createContextualFragment() would be useful here but is
            		// only relatively recently standardized and is not supported in
            		// some browsers (IE9, for one)
            		var el = document.createElement("div");
			var starttext = document.createTextNode('\u00A0');
			var endtext = document.createTextNode('\u00A0');

			if (isFirefox) {	// For Firefox browser we add whitespace to the start and end of the inserted button
                                el.appendChild(starttext);
                                el.appendChild($btn);
                                el.appendChild(endtext);
                        } else {
                                el.appendChild($btn);
                        }
			
            		var frag = document.createDocumentFragment(), node, lastNode;
            		while ( (node = el.firstChild) ) {
                		lastNode = frag.appendChild(node);
            		}
            		range.insertNode(frag);

            		// Preserve the selection
            		if (lastNode) {
                		range = range.cloneRange();
                		range.setStartAfter(lastNode);
                		range.collapse(true);
                		sel.removeAllRanges();
                		sel.addRange(range);
            		}
        	}
    	} else if (document.selection && document.selection.type != "Control") {
        	// IE < 9
        	document.selection.createRange().appendChild($btn);
    	}
}
// ############### End of insertButtonAtCaret function

function clearSeqArea($area) {	// This function handles clearing of the dynamic areas on the creation and editing pages for STB Groups, Sequences, and Events Schedule
	document.getElementById($area).innerHTML = '';
	//sequenceIndex = '1';
}
// ############### End of clearSeqArea function

function removeFromSeq($this,$area) {	// This function handles removing specific elements from the dynamic areas on the creation and editing pages for STB Groups, Sequences, and Events Schedule
	var rem = document.getElementById($this);
	if (!$area) {
		$area = 'sequenceArea';
	}

	document.getElementById($area).removeChild(rem);

	if (isFirefox) {
                var data = document.getElementById($area).innerHTML;
                var newdata = data.replace(/(?:\&nbsp;){3,}/g, "\&nbsp\;\&nbsp\;");
                document.getElementById($area).innerHTML = newdata;
        }
}
// ############### End of removeFromSeq function

function addSeqTO() {	// This function handles adding of Timeouts to the dynamic area on the Sequences creation/editing pages
	var timeout = document.getElementById('timeoutList').value;
	var id = 't' + timeout;
	var text = 'Timeout (' + timeout + 's)';
	seqTextUpdate(id,text);
}
// ############### End of addSeqTO function

function addSeqGroup() {	// This function handles adding of STB Groups to the dynamic area on the Events Schedule creation/editing pages
	var group = document.getElementById('groupList').value;
	if(!group) {
		return;
	}
	seqTextUpdate(group,group);
}
// ############### End of addSeqGroup function

function addSeqSequence() {	// This function handles adding of Sequences to the dynamic area on the Events Schedule creation/editing pages
	var seq = document.getElementById('seqList').value;
	if(!seq) {
		return;
	}
	seqTextUpdate(seq,seq,'sequenceEventArea');
}
// ############### End of addSeqGroup function

function seqValidate($origname) {	// This function handles validation and submitting of the data on the Sequences creation/editing pages
	var name = document.getElementById('sequenceName').value;
	var regex = /\S+/;
	var match = regex.exec(name);
	var invalidnameregex = /[^\w\s]|\_+/;	// Check the sequence name does not contain any non alphanumeric characters along with "_"
	var invalidnamematch = invalidnameregex.exec(name);
	if (!name) {
		alert('Please give the new sequence a name!');
	} else {
		if (!match) {
			alert('Please give the new sequence a name!');
		} else {
			if (invalidnamematch) {
				alert('Please only use letters, numbers, or spaces in the sequence name');
				return;
			}
			var elements = document.getElementById('sequenceArea').getElementsByTagName('input');
			var commands = [];
			for (var i = 0; i < elements.length; i++) {
				commands.push(elements[i].name);
			}
			if (!commands[0]) {
				alert('Your command sequence has nothing in it!');
			} else {
				if ($origname) {
					var string = commands.join(',');
					var text = '';
					if ($origname != name) {
						var xmlhttp;
						if (window.XMLHttpRequest) {// code for IE7+, Firefox, Chrome, Opera, Safari
							xmlhttp=new XMLHttpRequest();
						} else {// code for IE6, IE5
							xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
						}	
						xmlhttp.open("GET","cgi-bin/scripts/sequenceControl.pl?action=Search&sequence=" + name, false);
						xmlhttp.send(null);
						var returned = xmlhttp.responseText;
						if (returned == 'Found') {
							var c = confirm('A sequence with the name "' + name + '" already exists (spaces are formatted to no more than one in a row), would you like to replace it with this new sequence?');
							if (c == false) {
								$('#sequenceName').val($origname);
								return;
							}
						}

						text = 'Success! Sequence "' + $origname + '" was update to "' + name + '"';
					} else {
						text = 'Success! Sequence "' + $origname + '" was updated';
					}
					alert(text);
					perlCall('','scripts/sequenceControl.pl','action','Edit','sequence',name,'commands',string,'originalName',$origname);
				} else {
					var xmlhttp;
					if (window.XMLHttpRequest) {// code for IE7+, Firefox, Chrome, Opera, Safari
						xmlhttp=new XMLHttpRequest();
					} else {// code for IE6, IE5
						xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
					}
					xmlhttp.open("GET","cgi-bin/scripts/sequenceControl.pl?action=Search&sequence=" + name, false);
					xmlhttp.send(null);
					var returned = xmlhttp.responseText;
					if (returned == 'Found') {
						var c = confirm('A sequence with the name "' + name + '" already exists (spaces are formatted to no more than one in a row), would you like to replace it with this new sequence?');
						if (c == false) {
							return;
						}
					}

					var string = commands.join(',');
					alert('Success! Event "' + name + '" has been created');
					perlCall('','scripts/sequenceControl.pl','action','Add','sequence',name,'commands',string);
				}

				pageCall('dynamicPage','web/sequencesPage.html');
                		setTimeout(function(){perlCall('sequencesAvailable','scripts/pages/sequencesPage.pl','action','Menu')},200);
			}
		}
	}
}
// ############### End of seqValidate function

function deleteSequence($seq) {	// This function handles deletion of an existing sequence
	var c = confirm('Are you sure you want to delete the sequence "' + $seq + '" ?');
	if (c == false) {
		return;
	}
	
	if (c == true) {
		perlCall('','scripts/sequenceControl.pl','action','Delete','sequence',$seq);
		alert($seq + ' was deleted');
		pageCall('dynamicPage','web/sequencesPage.html');
		perlCall('sequencesAvailable','scripts/pages/sequencesPage.pl','action','Menu');
	}
}
// ############### End of deleteSequence function

function copySequence($seq) {
        var newseq = prompt("Please give the copied sequence a different name to the orignal \"" + $seq + "\"");
        if (!newseq) {
                return;
        } else {
                if (newseq == $seq) {
                        alert('The new name cannot be the same as the sequence being copied');
                        return;
                }

                if (newseq.match(/\S+/)) {
                        if (!newseq.match(/[^\w\s]|\_+/)) {
                                var xmlhttp;
                                if (window.XMLHttpRequest) {// code for IE7+, Firefox, Chrome, Opera, Safari
                                        xmlhttp=new XMLHttpRequest();
                                } else {// code for IE6, IE5
                                        xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
                                }
                                xmlhttp.open("GET","cgi-bin/scripts/sequenceControl.pl?action=Search&sequence=" + newseq, true);
                                xmlhttp.onreadystatechange=function(){
                                        if (xmlhttp.readyState==4) {
                                                var returned = xmlhttp.responseText;
                                                if (returned == 'Found') {
                                                        alert("A sequence already exists with the name \"" + newseq + "\". Please choose a different name");
                                                        return;
                                                } else {
                                                        perlCall('','scripts/sequenceControl.pl','action','Copy','sequence',newseq,'originalName',$seq);
                                                        newseq = newseq.toUpperCase();
                                                        alert("The sequence \"" + $seq + "\" was successfully copied to \"" + newseq + "\"");
                                                        pageCall('dynamicPage','web/sequencesPage.html');
                                                        setTimeout(function(){perlCall('sequencesAvailable','scripts/pages/sequencesPage.pl','action','Menu')},200);
                                                }
                                        }
                                }
                                xmlhttp.send(null);
                        } else {
                                alert('The new sequence name can only contain letters, numbers, and spaces');
                                return;
                        }
                } else {
                        alert('The new sequence name cannot be blank!');
                        return;
                }
        }
}
// ############### End of copySequence function

function editSequencePage($seq) {	// This function handles the first part of editing an existing sequence (Initial page load)
	var xmlhttp;
        if (window.XMLHttpRequest) {// code for IE7+, Firefox, Chrome, Opera, Safari
                xmlhttp=new XMLHttpRequest();
        } else {// code for IE6, IE5
                xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
        }
        xmlhttp.open("GET","cgi-bin/scripts/pages/sequencesPage.pl?action=Edit&sequence=" + $seq, true);
        xmlhttp.onreadystatechange=function(){
                if (xmlhttp.readyState==4) {
			document.getElementById('dynamicPage').innerHTML = xmlhttp.responseText;
			editSequencePage2($seq);
		}
	}
	xmlhttp.send(null);
}
// ############### End of editSequencePage function

function editSequencePage2($seq) {	// This function handles the second part of editing an existing sequence (Existing sequence data load)
	var xmlhttp;
        if (window.XMLHttpRequest) {// code for IE7+, Firefox, Chrome, Opera, Safari
        	xmlhttp=new XMLHttpRequest();
      	} else {// code for IE6, IE5
        	xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
      	}
      	xmlhttp.open("GET","cgi-bin/scripts/sequenceControl.pl?action=Show&sequence=" + $seq, true);
	xmlhttp.onreadystatechange=function(){
        	if (xmlhttp.readyState==4) {
		     	var returned = xmlhttp.responseText;
			var commands = returned.split(',');
			for (var i = 0; i < commands.length; i++) {
				var id = commands[i];
				var text = id;
				var tregex = /t(\d+)/;
				var timeoutmatch = tregex.exec(id);

				if (timeoutmatch) {
					var newtext = 'Timeout (' + timeoutmatch[1] + 's)';
					seqTextUpdate(id,newtext);
				} else {				
					if (id == 'tv guide') {
						text = 'TV Guide';
					}
					if (id == 'passive') {
						text = 'Deep Sleep';
					}
					text = text.replace("cursor ","");
					var bits = text.split(" ");
					var newtext = '';
					for (var o = 0; o < bits.length; o++) {
						var chunk = bits[o];
						newtext += chunk[0].toUpperCase() + chunk.slice(1);
						newtext += ' ';
					}
					seqTextUpdate(id,newtext);
				}
			}	
		}
	}
    	xmlhttp.send(null);
}
// ############### End of editSequencePage2 function

function groupValidate($origname) {	// This function handles validation and submitting of data on the STB Groups creation/editing pages
	var name = document.getElementById('groupName').value;
	var regex = /\S+/;
	var match = regex.exec(name);
	var invalidnameregex = /[^\w\s]|\_+/;	// Check the group name does not contain any non alphanumeric characters along with "_ + -"
	var invalidnamematch = invalidnameregex.exec(name);
	
	if (!name) {
		alert('Please give the new group a name!');
	} else {
		if (!match) {
			alert('Please give the new group a non-blank name!');
		} else {
			if (invalidnamematch) {
				alert('Please only use letters, numbers, or spaces in the group name');
				return;
			}
			var elements = document.getElementById('sequenceArea').getElementsByTagName('input');
			var members = [];
			for (var i = 0; i < elements.length; i++) {
				members.push(elements[i].name);
			}
			if (!members[0]) {
				alert('Your group has no members!');
			} else {
				if ($origname) {
					var string = members.join(',');
					var text = '';
					if ($origname != name) {
						var xmlhttp;
						if (window.XMLHttpRequest) {// code for IE7+, Firefox, Chrome, Opera, Safari
							xmlhttp=new XMLHttpRequest();
						} else {// code for IE6, IE5
							xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
						}
						xmlhttp.open("GET","cgi-bin/scripts/stbGroupControl.pl?action=Search&group=" + name, false);
						xmlhttp.send(null);
						var returned = xmlhttp.responseText;
						if (returned == 'Found') {
							var c = confirm('A group with the name "' + name + '" already exists (spaces are formatted to no more than one in a row), would you like to replace it with this new group?');
							if (c == false) {
								$('#groupName').val($origname);
								return;
							}
						}

						text = 'Success! Group "' + $origname + '" was update to "' + name + '"';
					} else {
						text = 'Success! Group "' + $origname + '" was updated';
					}
					alert(text);
					perlCall('','scripts/stbGroupControl.pl','action','Edit','group',name,'stbs',string,'originalName',$origname);
				} else {
					var xmlhttp;
					if (window.XMLHttpRequest) {// code for IE7+, Firefox, Chrome, Opera, Safari
						xmlhttp=new XMLHttpRequest();
					} else {// code for IE6, IE5
						xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
					}
					xmlhttp.open("GET","cgi-bin/scripts/stbGroupControl.pl?action=Search&group=" + name, false);
					xmlhttp.send(null);
					var returned = xmlhttp.responseText;
					if (returned == 'Found') {
						var c = confirm('A group with the name "' + name + '" already exists (spaces are formatted to no more than one in a row), would you like to replace it with this new group?');
						if (c == false) {
							return;
						}
					}
					var string = members.join(',');
					alert('Success! Group "' + name + '" has been created');
					perlCall('','scripts/stbGroupControl.pl','action','Add','group',name,'stbs',string);
				}

				pageCall('dynamicPage','web/stbGroupsPage.html');
                		setTimeout(function(){perlCall('stbGroupsAvailable','scripts/pages/stbGroupsPage.pl','action','Menu')},200);
			}
		}
	}
}
// ############### End of groupValidate function

function deleteGroup($grp) {	// This function handles deletion of an existing STB group
	var c = confirm('Are you sure you want to delete the group "' + $grp + '" ?');
	if (c == false) {
		return;
	}
	
	if (c == true) {
		perlCall('','scripts/stbGroupControl.pl','action','Delete','group',$grp);
		alert($grp + ' was deleted');
		pageCall('dynamicPage','web/stbGroupsPage.html');
		perlCall('stbGroupsAvailable','scripts/pages/stbGroupsPage.pl','action','Menu');
	}
}
// ############### End of deleteGroup function

function editGroupPage($grp) {	// This function handles the first part of editing of an existing STB group (Initial page load)
	//perlCall('dynamicPage','scripts/pages/stbGroupsPage.pl','action','Edit','group',$grp);
	var xmlhttp;
        if (window.XMLHttpRequest) {// code for IE7+, Firefox, Chrome, Opera, Safari
                xmlhttp=new XMLHttpRequest();
        } else {// code for IE6, IE5
                xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
        }
        xmlhttp.open("GET","cgi-bin/scripts/pages/stbGroupsPage.pl?action=Edit&group=" + $grp, true);
        xmlhttp.onreadystatechange=function(){
                if (xmlhttp.readyState==4) {
                        document.getElementById('dynamicPage').innerHTML = xmlhttp.responseText;
                        editGroupPage2($grp);
                }
        }
        xmlhttp.send(null);
	//setTimeout(function(){editGroupPage2($grp)},500);
}
// ############### End of editGroupPage function

function editGroupPage2($grp) {	// This function handles the second part of editing of an existing STB group (Existing group data load)
	var xmlhttp;
        if (window.XMLHttpRequest) {// code for IE7+, Firefox, Chrome, Opera, Safari
        	xmlhttp=new XMLHttpRequest();
      	} else {// code for IE6, IE5
        	xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
      	}
      	xmlhttp.open("GET","cgi-bin/scripts/stbGroupControl.pl?action=Show&group=" + $grp, true);
	xmlhttp.onreadystatechange=function(){
        	if (xmlhttp.readyState==4) {
		     	var returned = xmlhttp.responseText;
			var members = returned.split(',');
			for (var i = 0; i < members.length; i++) {
				var bits = members[i].split("~");
				var id = bits[0];
				var text = bits[1];
				var regex = /^\s*\:\s*$|^\s*\-\s*$/;	// If var text is like ':' or '-' it will be skipped from being added.
				var match = regex.exec(text);
				if (!match)  {
					seqTextUpdate(id,text);
				} else {
					alert('A box that was a member of this group has since been deconfigured or setup as a spacer. It will not be listed in the Group Members area below and will be removed from this group when you hit Update');
				}
			}	
		}
	}
    	xmlhttp.send(null);
}
// ############### End of editGroupPage2 function

function focusEl($element) {	// This function handles focussing on the given element on the page
	var xmlhttp;
        if (window.XMLHttpRequest){
                xmlhttp=new XMLHttpRequest();
        } else {
                xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
        }

        xmlhttp.onreadystatechange=function(){
                if (xmlhttp.readyState==4) {
                        document.getElementById($element).innerHTML=xmlhttp.responseText;
                }
        }
	var elem = '#' + $element;
	$(elem).focus();
}
// ############### End of focusEl function

function bindTrigger() {	// This function creates the event listener for handling radio buttons on the Events Schedule creation/editing pages
	$(".trigger").change(function() {
		if($(this).is(":checked")) {
			var name = $(this).attr('name');
			var value = $(this).attr('value');

			$('input[type=radio]').each(function(){
				var naym = $(this).attr('name');
				if(naym == name) {
					var val = $(this).attr('value');
					if (val != value) {
						$(this).prop('checked',false);
						$(this).attr('class','trigger radiooff');
					}
				}
			});
			$(this).attr('class','trigger radioon');
		}
	});
}
// ############### End of bindTrigger function

function eventScheduleEndHourControl() {
	var start = $('#everyhrstart').val();
	$('#everyhrend').empty();
	var newhtml = '';
	for (i = start;i < 24;i++) {
		var num = i;
		var res = /^\d$/.test(num);
		if (res) {
			num = '0' + i;
		}
		newhtml += "<option value='" + num + "'>" + num + '</option>';
	}
	//newhtml += "<option value='0'>0</option>";
	$('#everyhrend').html(newhtml);
}

function eventRadioSwitch($element) {
	$('input[type=radio]').each(function(){
		if ($(this).is(":checked")) {
			var parent = $(this).parents('td').attr('class','fancyCell highlighted');
			$(this).attr('class','trigger radioon');
		} else {
			var parent = $(this).parents('td').attr('class','fancyCell cellImportant');
			$(this).attr('class','trigger radiooff');
		}
	});
}

function newSchedValidate($event) {	// This function handles validation and submitting of data on the Events Schedule creation/editing pages
	var elements = document.getElementById('sequenceArea').getElementsByTagName('input');
	var members = [];
	for (var i = 0; i < elements.length; i++) {
		members.push(elements[i].name);
	}
	if (!members[0]) {
		alert('You have not selected any target STBs for this scheduled event!');
		return;
	}

	// Validate the selected sequences
	var seqels = document.getElementById('sequenceEventArea').getElementsByTagName('input');
	var seqs = [];
	for (var i = 0; i < seqels.length; i++) {
		seqs.push(seqels[i].name);
	}
	if (!seqs[0]) {
		alert('You have not selected any Sequences for this scheduled event!');
		return;
	}

	var mins = '';
	var hours = '';
	var starthrs = '';
	var endhrs = '';
	if($('input[value=everyxmins]').is(":checked")) {
		mins = '*/' + $('#everyminutes').val();
		if ($('#everyhrstart').val() == $('#everyhrend').val()) {
			hours = $('#everyhrend').val();
		} else { 
			hours = $('#everyhrstart').val() + '-' + $('#everyhrend').val();
		}
	} else {
		if($('input[value=normalmins]').is(":checked")) {
			mins = $('#minutes').val();
			hours = $('#hours').val();
		} else {
			alert('You have not used the radio buttons to choose when the event runs');
			return;
		}
	} 

	var days = '';
	if($('input[value=dayPresets]').is(":checked")) {
		days = $('#dayopts').val();
	} else {
		if($('input[value=dayCustom]').is(":checked")) {
			$('input[name=dayCheck]').each(function(){
				if( $(this).prop('checked') ) {
					var val = $(this).val();
					days += val + ',';
				}
			});

			if (!days) {
				alert('You have chosen "Custom Days" but not selected any days!');
				return;
			}
		} else {
			alert('You didnt choose from the Day Options!');
			return;
		}
	}

	var dom = $('#dom').val();
	var month = $('#month').val();
	var sequence = $('#seqList').val();
	var boxes = members.join(',');
	var sequences = seqs.join(',');
	var activestate = document.getElementById('eventActive').value;

	var wholething = activestate + '|' + mins + '|' + hours + '|' + dom + '|' + month + '|' + days + '|' + sequences + '|' + boxes;
		
	if ($event) {
		alert('Success! Your scheduled event was updated');
		perlCall('','scripts/eventScheduleControl.pl','action','Edit','eventID',$event,'details',wholething);
	} else {
		alert('Success! Your new scheduled event has been created');
		perlCall('','scripts/eventScheduleControl.pl','action','Add','eventID','','details',wholething);
	}
	pageCall('dynamicPage','web/eventsSchedulePage.html');
	setTimeout(function(){perlCall('evSchedsAvailable','scripts/pages/eventSchedulePage.pl','action','Menu')},200);
}
// ############### End of newSchedValidate function

function deleteSchedule($id) {	// This function handles deletion of an existing Scheduled Event
	var c = confirm('Are you sure you want to delete this scheduled event?');
	if (c == false) {
       		return;
	}
	perlCall('','scripts/eventScheduleControl.pl','action','Delete','eventID',$id);
	setTimeout(function(){perlCall('evSchedsAvailable','scripts/pages/eventSchedulePage.pl','action','Menu')},200);
}
// ############### End of deleteSchedule function

function scheduleStateChange($state,$id) {	// This function handles enabling and disabling of exisiting Scheduled Events
	var msg;
	if ($state == 'Enable') {
		msg = 'Are you sure you want to enable this scheduled event?';
	}
	if ($state == 'Disable') {
		msg = 'Are you sure you want to disable this scheduled event?';
	}

	var c = confirm(msg);
	if (c == false) {
		return;
	}

	perlCall('','scripts/eventScheduleControl.pl','action',$state,'eventID',$id);
	setTimeout(function(){perlCall('evSchedsAvailable','scripts/pages/eventSchedulePage.pl','action','Menu')},200);
}
// ############### End of scheduleStateChange function

function editSchedulePage($event) {	// This function handles the first part of editing an exisiting Scheduled Event (Initial page load)
	var xmlhttp;
        if (window.XMLHttpRequest) {// code for IE7+, Firefox, Chrome, Opera, Safari
                xmlhttp=new XMLHttpRequest();
        } else {// code for IE6, IE5
                xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
        }
        xmlhttp.open("GET","cgi-bin/scripts/pages/eventSchedulePage.pl?action=Edit&event=" + $event, true);
        xmlhttp.onreadystatechange=function(){
                if (xmlhttp.readyState==4) {
                        document.getElementById('dynamicPage').innerHTML = xmlhttp.responseText;
                        editSchedulePage2($event);
                }
        }
        xmlhttp.send(null);
}
// ############### End of editSchedulePage function

function editSchedulePage2($event) {	// This function handles the second part of editing an exisiting Scheduled Event (Existing event data load)
	var xmlhttp;
        if (window.XMLHttpRequest) {// code for IE7+, Firefox, Chrome, Opera, Safari
        	xmlhttp=new XMLHttpRequest();
      	} else {// code for IE6, IE5
        	xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
      	}
      	xmlhttp.open("GET","cgi-bin/scripts/eventScheduleControl.pl?action=Show&eventID=" + $event, true);
	xmlhttp.onreadystatechange=function(){
                if (xmlhttp.readyState==4) {
		     	var returned = xmlhttp.responseText;
			var stbregex = /Boxes\{(.+)\}Sequences/;
			var seqregex = /Sequences\{(.+)\}/;

			var stbmatch = stbregex.exec(returned);
			var seqmatch = seqregex.exec(returned);

			var members = stbmatch[1].split(',');
			for (var i = 0; i < members.length; i++) {
				var bits = members[i].split("~");
				var id = bits[0];
				var text = bits[1];
				var regex = /^\s*\:\s*$|^\s*\-\s*$/;    // If var text is like ':' or '-' it will be skipped from being added.
		                var match = regex.exec(text);
		                if (!match)  {
					seqTextUpdate(id,text);
				} else {
					alert('WARNING: A box that was included in this scheduled event has since been deconfigured or setup as a spacer. It will not be listed in the Target STB area below and will be removed from this Scheduled Event when you hit Update');
				}
			}

			var sequences = seqmatch[1].split(',');
			for (var i = 0; i < sequences.length; i++) {
				var bits = sequences[i].split("~");
                                var id = bits[0];
                                var text = bits[1];
				if (text.match(/^-$/)) {
					alert('WARNING: A sequence that was included in this scheduled event could not be found. It may have been renamed or deleted. Please verify the sequences and update this scheduled event.');
				} else {
					seqTextUpdate(id,text,'sequenceEventArea');
				}
			}

		}
	}
    	xmlhttp.send(null);
}
// ############### End of editSchedulePage2 function


function stbTypeChoice($option) {	// This function handles changing of an STB type in the STB Data page. It loads the appropriate control data input fields according to its control type i.e. Dusky, Bluetooth, etc
	var tag = 'print' + $option;
	var stb = document.getElementById("stbname").value;
	if ($option.match(/Network/)) {
		alert('NOTE: For network control to work, the STB MUST be on the same network as the machine hosting this controller');
	}
	perlCall('typeChange','scripts/pages/stbDataPage.pl','option',tag,'stb',stb);
}
// ############### End of stbTypeChoice function

function daysSelectedCheck() {	// This function suggests to the user to use the "Everyday" option in the "Day Presets" section on the Event Schedule creation/editiing pages if they have chosen "Custom Days" and then checked ALL of the days
	var checked = 0;

	$('input[name=dayCheck]').each(function(){
		if( $(this).prop('checked') ) {
			checked++;
   		}
      	});

	if (checked == '7') {
		alert('You have selected all of the custom days. Why not use "Everyday" in the Day Presets section?');
	}
}
// ############### End of daysSelectedCheck function

function clearSTBDataForm() {	// This function handles clearing of the current date in all fields on the STB Data editing page
	var conf = confirm('Are you sure you want to clear all data for this STB?');
	if (conf == false) {
		return;
	}

	$('input[type=text]').each(function(){
        	$(this).val('');
	});	

	$('select').each(function(){
		var id = $(this).attr('id');
		var first = $('#' + id + " option:first").val();
        	$(this).val(first);
		if (id == 'type') {
			stbTypeChoice(first);
		}
	});	
}
// ############### End of clearSTBDataForm function

function scheduleAdmin($option) {	// This function handles the Events Scheduler admin buttons (Disable Scheduler,Enable Scheduler,Kill All,Pause All, Resume All)
	var msghash = {};
	msghash['DisableSchedule'] = 'disable the scheduler';
	msghash['EnableSchedule'] = 'enable the scheduler';
	msghash['KillAll'] = 'kill all currently running scheduled events';
	msghash['PauseAll'] = 'pause all currently running scheduled events';
	msghash['ResumeAll'] = 'resume all currently paused scheduled events';

	var conf = confirm('Are you sure you want to ' + msghash[$option] + '?');
	if (conf == false) {
		return;
	}

	perlCall('','scripts/eventScheduleControl.pl','action',$option);
        setTimeout(function(){perlCall('evSchedsAvailable','scripts/pages/eventSchedulePage.pl','action','Menu')},200);	
	setTimeout(function(){announcements()},200);
}
// ############### End of scheduleAdmin function

function addGroupMulti($sel) {
	var btns = document.querySelectorAll("[data-loc]");
	var regex = '';

	if ($sel.match(/row/)) {
		regex = new RegExp($sel + "$");
	} else if ($sel.match(/col/)) {
		regex = new RegExp ($sel + 'row');
	} else {
		alert('Selection error');
		return;
	}

	for (var i = 0; i < btns.length; i++) {
		var data = btns[i].getAttribute('data-loc');
		var match = regex.exec(data);
		if (match) {
			//matches++;
			btns[i].click();
		}
	}
}
// ############### End of addGroupMulti function

// end hiding script from old browsers -->
