<!-- hide script from old browsers
var isFirefox = typeof InstallTrigger !== 'undefined';
var seqnamereq;
var seqpos;
var seqpos2;
var range;	// ##### This variable holds data on the range that controls adding nodes to the sequence areas
var schedseqpos;
var schedseqcarpos;
var schedseqrange;
var lastgroupselected = '';	// GLOBAL variable to store last selected group for STB control
var stbHash = {};		// Create the GLOBAL stbHash object (hash) to handle selected STBs from the grid
var lastRow;			// Create the GLOBAL lastRow variable (scalar) to record last selected row
var lastRowHL;			// Create the GLOBAL lastRowHL variable (scalar) to record last highlighted row
var gridcontmode = 'stbgrid';	// GLOBAL variable to store the stb control mode. "stbs" or "groups"
var highlightedSTBs = {};	// Create the GLOBAL highlightedSTBs variable (hash)

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
                        	//setTimeout(function() {
                        	//	$('.tooltip').remove();
                        	//},5000);
                        },
                        mouseleave: function() {
                                // Hover out code
                                $('.tooltip').remove();
                        },
                        click: function() {
                                // Hover out code
                                $('.tooltip').remove();
                        },
                        mousemove: function(e) {
                                var mousex = e.pageX + 20; //Get X coordinates
                                var mousey = e.pageY + 10; //Get Y coordinates
                                $('.tooltip').css({ top: mousey, left: mousex, 'z-index': 10})
                        }
                }, '.masterTooltip');
	});
	//Bind the function for the remote control selection
	$(document).on('change', '#remoteSelector', function() {
		remoteChange(this);
	});

	$(document).on('click', '.browse-btn', function() {
		$('#real-input').click();
	});

	$(document).on('click', '.menuBtn', function() {
		seqpos2 = '';
		range = '';
		schedseqpos = '';
		schedseqrange = '';
	});

	// This controls the on change function of the input field for selecting a STRESS sequence file for input
	$(document).on('change', '#real-input', function() {
		var uploadButton = document.querySelector('.browse-btn');
		var fileInfo = document.querySelector('.file-info');
		var realInput = document.getElementById('real-input');
		var name = realInput.value.split(/\\|\//).pop();
		if (!name.match(/\.txt$/)) {
			alert('ERROR: The file you have selected does not appear to be a .txt file. Please try again');
			fileInfo.innerHTML = 'Select script for upload';
			realInput.value = '';
			$('#importStressBtn').attr("disabled","true");
		} else if (name.length > 28) {
			alert('The length of your import file name exceeds 25 characters which is the limit for new sequence names. You will have to provide a new name for the imported sequences.');
			seqnamereq = 'true';
			var short = shorten(name,28)
			fileInfo.innerHTML = short;
			if (!$('#importStressName').val().match(/\S+/)) {
				$('#importStressBtn').attr("disabled","true");
			}
		} else {
			var short = shorten(name,28)
			fileInfo.innerHTML = short;
			$('#importStressBtn').removeAttr("disabled");
			seqnamereq = '';
		}
	});

	$(document).on('input', '#importStressName', function() {
		if (!$('#importStressName').val().match(/\S+/) && (seqnamereq)) {
			$('#importStressBtn').attr("disabled","true");
		} else if (!$('#real-input').val().match(/\S+/)) {
			$('#importStressBtn').attr("disabled","true");
		} else {
			$('#importStressBtn').removeAttr("disabled");
		}
	});

	$(document).on('click', '.browse-btn2', function() {
		$('#real-input2').click();
	});

	// This controls the on change function of the input field for selecting a NATIVE sequence file for input
	$(document).on('change', '#real-input2', function() {
		var uploadButton = document.querySelector('.browse-btn2');
		var fileInfo = document.querySelector('.file-info2');
		var realInput = document.getElementById('real-input2');
		var name = realInput.value.split(/\\|\//).pop();
		if (!name.match(/\.txt$|\.json$/i)) {
			alert('ERROR: The file you have selected does not appear to be a .txt file. Please try again');
			fileInfo.innerHTML = 'Select script for upload';
			realInput.value = '';
			$('#importNativeBtn').attr("disabled","true");
		} else {
			var short = shorten(name,28)
			fileInfo.innerHTML = short;
			$('#importNativeBtn').removeAttr("disabled");
		}
	});

	$(document).on('keyup click', '#sequenceArea', function() {
		logSeqCaratPos();
	});
	$(document).on('keyup click', '#sequenceEventArea', function() {
		logSchedSeqCaratPos();
	});
	$(document).on('click', '.gridModeDiv', function() {
		gridModeSwitch(this);
	});

	$(document).on('click', '.groupSTBControlRow', function() {
		groupSTBControl(this);
	});
}

function shorten (fullStr, strLen, separator) {
	if (fullStr.length <= strLen) return fullStr;

	separator = separator || '...';

	var sepLen = separator.length,
	charsToShow = strLen - sepLen,
	frontChars = Math.ceil(charsToShow/2),
	backChars = Math.floor(charsToShow/2);

	return fullStr.substr(0, frontChars) + 
	separator + 
	fullStr.substr(fullStr.length - backChars);
};

window.onunload = window.onbeforeunload = function ()  {	// Run the logLastBoxes function when the page is unloaded (Refreshed or tab is navigated to elsewhere
	logLastBoxes();
}

function dateTime() {	// This function handles the updating of the real time server clock on the main page
	$.ajax({
		type : 'GET',
		url : 'cgi-bin/scripts/showTime.pl',
		success : function(result) {
			var bits = result.split(',');
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
				var div = $('#dateTimeDiv');
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
	        	                $('#dateTimeDiv').html('<p>' + datestring + '</p>');	// Update the html in div 'dateTimeDiv' with the new date info
        	        	}
	        	},1000);
		}
	});
}
// ############### End of dateTime function

function announcements() {	// This function handles the server announcements section on the main page. It is only used for scheduled events info
	var div = $('#messages');
	if (div) {
		$.ajax({
			type : 'GET',
			url : 'cgi-bin/scripts/messages.pl',
			success : function(result) {
				div.html('<p>' + result + '</p>');
			}
		});
	}
	return;
}
// ############### End of announcements function

function dynamicTitle($option) {	// This function handles the editing of the Title of the main page
	if ($option == 'get') {
        	var date = Date();
		$.ajax({
			type : 'GET',
			url : 'web/dynamicTitle.txt?' + date,
			success : function(result) {
				if (!result) {
					$('#dynamicTitle').text('Click here to change the default title!');
				} else {
					if (!result.match(/\S+/)) {
						$('#dynamicTitle').text('Click here to change the default title!');
					} else {
						if (result.match(/404 not found/i)) {
							$('#dynamicTitle').text('Click here to change the default title!');
						} else {
							$('#dynamicTitle').text(result);
						}
					}
				}
			},
			error : function() {
				$('#dynamicTitle').text('Click here to change the default title!');
			}
		});
	} else if ($option == 'set') {
		var current = $('#dynamicTitle').text();
		var newtitle = prompt("Please enter your new page title",current);
		if (!newtitle) {
			return;
		} else {
			if (newtitle == current) {
				return;
			}
			if (!newtitle.match(/\S+/)) {
				var conf = confirm('Your new page title is blank. If you select ok, the page title will be returned to the default. Do you want to proceed?');
				if (conf == false) {
					return;
				}
			}
			$.ajax({
				type : 'POST',
				url : 'cgi-bin/scripts/editPageTitle.pl',
				data : {
					'title' : newtitle,
				},
				success : function(result) {
					alert('Title updated successfully!');
					dynamicTitle('get');
				},
				error : function(xhr) {
					alert('The request failed:' + xhr.statusText);
				}
			});
		}
	}
	return;
}
// ############### End of dynamicTitle function

function stbControl($action,$commands) {	// This function handles the control of STBs from the STB Grid
	var comstring = '';
	if (gridcontmode.match(/stbgroups/)) {
		if (lastgroupselected) {
			//console.log('Sending group control to group ' + lastgroupselected);
			var groupname = $('#'+lastgroupselected).find('.groupControlRowSection:first').text();
			//alert(groupname);
			//return;
			comstring = groupname;
		} else {
			alert('You have not selected any groups to be controlled!');
			return;
		}
	} else {
		for (var key in stbHash) {
			comstring += key + ',';
		}
	}

	var comstring2 = comstring.replace(/,$/,''); // Remove any trailing commas from comstring

	// Validate whether any STBs have been selected for control. Return if none have
	if (!comstring2) {
		alert('No valid STBs have been selected for control');
		return;
	}

	// For STB control requests, we just need to fire the event and NOT wait for script output
	$.ajax({
                type: 'get',
                timeout: 500,	// Force the Ajax call to timeout after half a second
                url: 'cgi-bin/scripts/stbControl.pl',
                data: { 'action' : $action,
                        'command' : $commands,
                        'info' : comstring2
                },
        });
}
// ############### End of stbControl function

function perlCall ($element, $script, $param1, $value1, $param2, $value2, $param3, $value3, $param4, $value4, $param5, $value5) {	// This function allows running of any script from within this javascript
	var regex = /\S+/;
	var elemmatch = regex.exec($element);

	var dataObj = {};
	if ($param1) {dataObj[$param1] = $value1}
	if ($param2) {dataObj[$param2] = $value2}
	if ($param3) {dataObj[$param3] = $value3}
	if ($param4) {dataObj[$param4] = $value4}
	if ($param5) {dataObj[$param5] = $value5}

	$.ajax({
		type: 'GET',
		url: 'cgi-bin/' + $script,
		data: dataObj,
		success : function(result) {
			if (elemmatch) {
				$('#' + $element).html(result);
			}
		}
	});

	// Reset the sequenceIndex to 1
	sequenceIndex = '1';
}
// ############### End of perlCall function

function scriptCall($element,$script,$data) {

	$.ajax({
		type: 'GET',
		url: 'cgi-bin/' + $script,
		data: $data,
		success : function(result) {
			if ($element) {
				$('#' + $element).html(result);
			}
		}
	});

	// Reset the sequenceIndex to 1
	sequenceIndex = '1';
}

function pageCall ($element, $page) {	// This function allows calling of html pages
	$.ajax({
		type: 'GET',
		url: $page,
		success : function(result) {
			$('#' + $element).html(result);
		},
		error : function() {
			alert('Oops an error occurred when accessing that page. If the problem persists, contact you system administrator for assistance');
		}
	});
}
// ############### End of pageCall function

function controllerPage() {
	if (!gridcontmode) {
		gridcontmode = 'stbgrid';
	}
	$.ajax({
		type: 'GET',
		url: 'cgi-bin/scripts/pages/stbGrid.pl',
		data: {
			'mode' : gridcontmode,
			'wholepage' : 'true'
		},
		success : function(result) {
			$('#dynamicPage').html(result);
			if (gridcontmode.match(/stbgrid/)) {
				getLastBoxes();
			} else if (gridcontmode.match(/stbgroups/)) {
				if (lastgroupselected) {
					$('#' + lastgroupselected).click();
					$('#groupControlListHolder').animate({
					        scrollTop: $('#groupControlListHolder #' + lastgroupselected).position().top
					}, 'slow');
				}
			}
		},
		error : function() {
			alert('Oops an error occurred when accessing that page. If the problem persists, contact you system administrator for assistance');
		}
	});
}

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
		} else {
			console.log('No last boxes found');
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

	if (x > 24) {
		var c = confirm('You have chosen to have more than the recommended maximum of 24 columns. This can cause layout problems. Do you want to continue?');
		if (c == false) {
			return;
		}
	}

	if (y > 24) {
		var c = confirm('You have chosen to have more than the recommended maximum of 50 rows. This can cause layout problems. Do you want to continue?');
		if (c == false) {
			return;
		}
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

	// Check the STB name only contains valid characters
        var vcharsregex = new RegExp(/([^a-zA-Z0-9\.\-\:\_ ])/g);
        if (name.match(vcharsregex)) {
                alert('STB Name can only contain letters, numbers, or the following special characters . - _ :');
                return;
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
			success : function(result) {
				if (result.match(/Success/)) {
					var conf = confirm("STB data updated successfully\n\nClick OK to return to the STB Data grid or Cancel to remain on this page");
					if (conf == true) {
						$('#menuSTBData').click();
					}
				} else {
					alert('ERROR: STB data settings failed to update, please try again or contact your system administrator if the problem persists.');
				}
			}
                });
        });
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
	if (!$id) {
		return;
	}
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

	var restrict = $('#restrictSTBGridRows').val();
	if (restrict) {
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

function rows($row) {	// This function handles the row selection buttons on the STB grid
	var row = document.getElementById($row);			// Save the $row data in var 'row'
	var count = row.getElementsByTagName("button");			// Get the array of buttons within the row
	var override;
	var highlight;
	if(lastRowHL == $row) {
		lastRow = $row;
		lastRowHL = '';
		override = 'selected';
	} else {
		if(lastRow == $row) {
			override = 'highlighted';
			lastRowHL = $row;
			lastRow = '';
		} else {
			lastRow = $row;
			lastRowHL = '';
			override = 'selected';
			for (var stb in highlightedSTBs) {
				document.getElementById(stb).className = 'stbButton deselect';
			}
			highlightedSTBs = {};
		}
	}

	var restrict = $('#restrictSTBGridRows').val();
	if (restrict) {
		for (var stb in stbHash) {
		      document.getElementById(stb).className = 'stbButton deselect';
		}
		stbHash = {};
	}

	for(var i=0;i<count.length;i++) {	// While 'i' is less than the number of cells
		var ayedee = count[i].id;	// Get the buttons id and save it to 'ayedee'
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
	if (gridcontmode.match(/groups/)) {
		alert('Feature not available with STB Groups control mode');
		return;
	}
	var restrict = $('#restrictSTBGridRows').val();
	if (!restrict) {
		alert('This feature is disabled while the "STB Grid Row Selection" option is disabled in the settings.');
		return;
	}

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
		$area = 'sequenceArea';
	}

	if ($id.match(/^STB\d+$/)) {
		var exists = $('#' + $area).find("[name='" + $id + "']")[0];
		if (exists) {
			var text = $(exists).attr("value");
			alert('This STB is already selected');
			return;
		}
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

var lastset;
function insertButtonAtCaret($btn,$area) {	// This function handles the second part of adding STBs and Commands in to the dynamic areas on the STB Groups, Sequences, and Events Schedule creation and editing pages
	if (!$area) {
		$area = 'sequenceArea';
	}

    	$('#' + $area).focus();
    	var sel;
    	if (window.getSelection) {
		// IE9 and non-IE
		sel = window.getSelection();
		if (!range){
        		if (sel.getRangeAt && sel.rangeCount) {
            			range = sel.getRangeAt(0);
            			range.deleteContents();
			}
		} else {
			if (seqpos2){
				range.setStartAfter(seqpos2);
			}
		}
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
        		seqpos2 = lastNode;
			range.collapse(true);
        		sel.removeAllRanges();
        		sel.addRange(range);
    		}
    	} else if (document.selection && document.selection.type != "Control") {
        	// IE < 9
        	document.selection.createRange().appendChild($btn);
    	}
}
// ############### End of insertButtonAtCaret function

function clearSeqArea($area) {	// This function handles clearing of the dynamic areas on the creation and editing pages for STB Groups, Sequences, and Events Schedule
	document.getElementById($area).innerHTML = '';
	seqpos2 = '';
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

	// ##### Once you remove a child node from the sequence area, we need to locate the last child node in that div
	// ##### If there aren't any (sequence area is empty), reset the last node variable "seqpos2" to null
	var ln = document.getElementById('sequenceArea').lastChild;
	if (ln) {
		seqpos2 = ln;
	} else {
		seqpos2 = '';
	}
}
// ############### End of removeFromSeq function

function addSeqTO() {	// This function handles adding of Timeouts to the dynamic area on the Sequences creation/editing pages
	var timeout = document.getElementById('seqTimeoutText').value;
	if (!timeout) {
		alert('Please enter a timeout value in seconds');
		return;
	} else if (timeout.match(/[^0-9]/)) {
		alert('Timeout must be a numeric value');
		return;
	}
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
	schedSeqTextUpdate(seq,seq,'sequenceEventArea');
}
// ############### End of addSeqGroup function

function seqValidate($origname) {	// This function handles validation and submitting of the data on the Sequences creation/editing pages
	var name = document.getElementById('sequenceName').value;
	var regex = /\S+/;
	var match = regex.exec(name);
	var invalidnameregex = /[^\w\s]|\_+/;	// Check the sequence name does not contain any non alphanumeric characters along with "_"
	var invalidnamematch = invalidnameregex.exec(name);
	var $seqdesc = $('#sequenceDesc').val();
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
						$.ajax({
							type : 'GET',
							url : 'cgi-bin/scripts/sequenceControl.pl',
							data : {
								'action' : 'Search',
								'sequence' : name,
							},
							success : function(result) {
								if (result == 'Found') {
									var c = confirm('A sequence with the name "' + name + '" already exists (spaces are formatted to no more than one in a row), would you like to replace it with this new sequence?');
									if (c == false) {
										$('#sequenceName').val($origname);
										return;
									}
								}
							}
						});
					}			//console.log('New description passed');

					data = {};
					data['action'] = 'Edit';
					data['sequence'] = name;
					data['commands'] = string;
					data['originalName'] = $origname;
					data['description'] = $seqdesc;

					scriptCall('','scripts/sequenceControl.pl',data);
					alert('Success! Sequence "' + $origname + '" was updated');
					$('#menuSequences').click();
				} else {
					$.ajax({
						type : 'GET',
						url : 'cgi-bin/scripts/sequenceControl.pl',
						data : {
							'action' : 'Search',
							'sequence' : name,
						},
						success : function(result) {
							if (result == 'Found') {
								var c = confirm('A sequence with the name "' + name + '" already exists (spaces are formatted to no more than one in a row), would you like to replace it with this new sequence?');
								if (c == false) {
									return;
								}
							}
							var string = commands.join(',');
							data = {};
							data['action'] = 'Add';
							data['sequence'] = name;
							data['commands'] = string;
							data['description'] = $seqdesc;
							scriptCall('','scripts/sequenceControl.pl',data);
							alert('Success! Event "' + name + '" has been created');
							$('#menuSequences').click();
						}
					});
				}
			}
		}
	}
}
// ############### End of seqValidate function

function exportSequence($option,$seq) {	// This function handles exporting of single or multiple sequences
	var $list = '';		// This will be populated with the list of sequences to be exported when the Multi Export process is run
	if ($option.match(/show/)) {
		var $seqn = $seq.replace(/\s+/g,'_');
		$('#seqExportOverlay-' + $seqn).css('display','inline-block');
		return;
	}

	if ($seq.match(/multi-export/)) {
		$('.seqExpCheck').each(function() {
			if ($(this).is(':checked')) {
				var seqnm = $(this).attr('name');
				if (seqnm) {
					$list += seqnm + ',';
				}
			}
		});

		if (!$list) {
			alert('Please select at least one sequence to export');
			return;
		}
		//alert($list);
		//return;
	}

	$.ajax({
		type : 'GET',
		url : 'cgi-bin/scripts/sequenceControl.pl',
		data : {
			'action' : 'Export',
			'sequence' : $seq,
			'exportFormat' : $option,
			'list' : $list
		},
		success : function(result) {
			if (!result) {
				alert('ERROR: It looks like nothing came back from the export request. Please try again or contact your system administrator if the problem persists');
				return;
			} else if (result.match(/ERROR/)) {
				alert(result);
				return;
			} else if (result.match(/FILENAME=/)){
				var filename = result.replace('FILENAME=','');
				var d = new Date();
				var n = d.getTime();
				var path = '/exports/' + filename + '?' + n;
				var url = window.location + path;
				url = url.replace(/([^:])\/{2,}/g,"$1/");	// Remove any instances of more than one '/' character, apart from http://. Replace them with a single '/'
				// Validate the URL is reachable
				$.get(url).fail(function () {
				     	alert("ERROR: Unable to reach the address " + url + " for download. Please ensure you have linked the \"exports\" folder in your web server directory and it is accessible.\n\nView the README.txt file for instructions on how to do this.");
				     	return;
				});
				var elem = document.createElement('a');
				elem.href = url;
				elem.download = filename;
				document.body.appendChild(elem);
				elem.click();
				document.body.removeChild(elem);
			}
		}
	});

}
// ############### End of exportSequence function

function closeSeqExportDiv ($id) {
	$('#' + $id).css('display','none');
}

function deleteSequence($seq) {	// This function handles deletion of an existing sequence
	var c = confirm('Are you sure you want to delete the sequence "' + $seq + '" ?');
	if (c == false) {
		return;
	}

	if (c == true) {
		perlCall('','scripts/sequenceControl.pl','action','Delete','sequence',$seq);
		setTimeout(function() {
			$('#menuSequences').click();
		},500);
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
                                $.ajax({
                                	type : 'GET',
                                	url : 'cgi-bin/scripts/sequenceControl.pl',
                                	data : {
                                		'action' : 'Search',
                                		'sequence' : newseq,
                                	},
                                	success : function(result) {
                                		if (result == 'Found') {
							alert("A sequence already exists with the name \"" + newseq + "\". Please choose a different name");
							return;
                                		} else {
                                                        perlCall('','scripts/sequenceControl.pl','action','Copy','sequence',newseq,'originalName',$seq);
                                                        newseq = newseq.toUpperCase();
                                                        alert("The sequence \"" + $seq + "\" was successfully copied to \"" + newseq + "\"");
							$('#menuSequences').click();
                                		}
                                	}
                                });
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
	$.ajax({
		type : 'GET',
		url : 'cgi-bin/scripts/pages/sequencesPage.pl',
		data : {
			'action' : 'Edit',
			'sequence' : $seq,
		},
		success : function(result) {
			$('#dynamicPage').html(result);
			editSequencePage2($seq);
		}
	});
}
// ############### End of editSequencePage function

function editSequencePage2($seq) {	// This function handles the second part of editing an existing sequence (Existing sequence data load)
	$.ajax({
		type : 'GET',
		url : 'cgi-bin/scripts/sequenceControl.pl',
		data : {
			'action' : 'Show',
			'sequence' : $seq,
		},
		success : function(result) {
			var commands = result.split(',');
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
	});
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
						$.ajax({
							type : 'GET',
							url : 'cgi-bin/scripts/stbGroupControl.pl',
							data : {
								'action' : 'Search',
								'group' : name,
							},
							success : function(result) {
								if (result == 'Found') {
									var c = confirm('A group with the name "' + name + '" already exists (spaces are formatted to no more than one in a row), would you like to replace it with this new group?');
									if (c == false) {
										$('#groupName').val($origname);
										return;
									}
								}
								perlCall('','scripts/stbGroupControl.pl','action','Edit','group',name,'stbs',string,'originalName',$origname);
								text = 'Success! Group "' + $origname + '" was updated to "' + name + '"';
								alert(text);
								$('#menuGroups').click();
								//pageCall('dynamicPage','web/stbGroupsPage.html');
								//setTimeout(function(){perlCall('stbGroupsAvailable','scripts/pages/stbGroupsPage.pl','action','Menu')},200);
							}
						});
					} else {
						text = 'Success! Group "' + $origname + '" was updated';
						alert(text);
						perlCall('','scripts/stbGroupControl.pl','action','Edit','group',name,'stbs',string,'originalName',$origname);
						$('#menuGroups').click();
						//pageCall('dynamicPage','web/stbGroupsPage.html');
						//setTimeout(function(){perlCall('stbGroupsAvailable','scripts/pages/stbGroupsPage.pl','action','Menu')},200);
					}
				} else {
					$.ajax({
						type : 'GET',
						url : 'cgi-bin/scripts/stbGroupControl.pl',
						data : {
							'action' : 'Search',
							'group' : name,
						},
						success : function(result) {
							if (result == 'Found') {
								var c = confirm('A group with the name "' + name + '" already exists (spaces are formatted to no more than one in a row), would you like to replace it with this new group?');
								if (c == false) {
									return;
								}
							}
							var string = members.join(',');
							perlCall('','scripts/stbGroupControl.pl','action','Add','group',name,'stbs',string);
							alert('Success! Group "' + name + '" has been created');
							$('#menuGroups').click();
							//pageCall('dynamicPage','web/stbGroupsPage.html');
                					//setTimeout(function(){perlCall('stbGroupsAvailable','scripts/pages/stbGroupsPage.pl','action','Menu')},200);
						}
					});
				}
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
		$('#menuGroups').click();
		//pageCall('dynamicPage','web/stbGroupsPage.html');
		//perlCall('stbGroupsAvailable','scripts/pages/stbGroupsPage.pl','action','Menu');
	}
}
// ############### End of deleteGroup function

function editGroupPage($grp) {	// This function handles the first part of editing of an existing STB group (Initial page load)
	$.ajax({
		type : 'GET',
		url : 'cgi-bin/scripts/pages/stbGroupsPage.pl',
		data : {
			'action' : 'Edit',
			'group' : $grp,
		},
		success : function(result) {
                        $('#dynamicPage').html(result);
                        editGroupPage2($grp);
		}
	});
}
// ############### End of editGroupPage function

function editGroupPage2($grp) {	// This function handles the second part of editing of an existing STB group (Existing group data load)
	$.ajax({
		type : 'GET',
		url : 'cgi-bin/scripts/stbGroupControl.pl',
		data : {
			'action' : 'Show',
			'group' : $grp,
		},
		success : function(result) {
			var members = result.split(',');
			var deconfcnt = 0;
			for (var i = 0; i < members.length; i++) {
				var bits = members[i].split("~");
				var id = bits[0];
				var text = bits[1];
				var regex = /^\s*\:\s*$|^\s*\-\s*$/;	// If var text is like ':' or '-' it will be skipped from being added.
				var match = regex.exec(text);
				if (!match)  {
					seqTextUpdate(id,text);
				} else {
					deconfcnt++;
				}
			}
			if (deconfcnt) {
				alert(deconfcnt + ' STB(s) that were a member of this group have since been deconfigured or setup as a spacer. They will not be listed in the Group Members area below and will be removed from this group when you hit Update');
			}
		}
	});
}
// ############### End of editGroupPage2 function

function focusEl($element) {	// This function handles focussing on the given element on the page
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
	$('#everyhrend').html(newhtml);
}

function eventRadioSwitch($element) {
	$('input[type=radio]').each(function(){
		if ($(this).is(":checked")) {
			$(this).attr('class','trigger radioon');
		} else {
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
		perlCall('','scripts/eventScheduleControl.pl','action','Edit','eventID',$event,'details',wholething);
		alert('Success! Your scheduled event was updated');
	} else {
		perlCall('','scripts/eventScheduleControl.pl','action','Add','eventID','','details',wholething);
		alert('Success! Your new scheduled event has been created');
	}
	$('#menuSchedule').click();
}
// ############### End of newSchedValidate function

function deleteSchedule($id) {	// This function handles deletion of an existing Scheduled Event
	var c = confirm('Are you sure you want to delete this scheduled event?');
	if (c == false) {
       		return;
	}
	perlCall('','scripts/eventScheduleControl.pl','action','Delete','eventID',$id);
	setTimeout(function() {
		$('#menuSchedule').click();
	},200);
}
// ############### End of deleteSchedule function

function copySchedule($id) {	// This function handles deletion of an existing Scheduled Event
	var c = confirm('Copying this scheduled event will mean you may have 2 sets of commands being sent to the same STBs at the same time which can cause issues. Be sure to amend the copied event to avoid clashes. Continue?');
	if (c == false) {
       		return;
	}
	perlCall('','scripts/eventScheduleControl.pl','action','Copy','eventID',$id);
	setTimeout(function() {
		$('#menuSchedule').click();
	},200);
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
	setTimeout(function() {
		$('#menuSchedule').click();
	},200);
}
// ############### End of scheduleStateChange function

function editSchedulePage($event) {	// This function handles the first part of editing an exisiting Scheduled Event (Initial page load)
	$.ajax({
		type : 'GET',
		url : 'cgi-bin/scripts/pages/eventSchedulePage.pl',
		data : {
			'action' : 'Edit',
			'event' : $event,
		},
		success : function(result) {
			$('#dynamicPage').html(result);
			editSchedulePage2($event);
		}
	});
}
// ############### End of editSchedulePage function

function editSchedulePage2($event) {	// This function handles the second part of editing an exisiting Scheduled Event (Existing event data load)
	$.ajax({
		type : 'GET',
		url : 'cgi-bin/scripts/eventScheduleControl.pl',
		data : {
			'action' : 'Show',
			'eventID' : $event,
		},
		success : function(result) {
			var stbregex = /Boxes\{(.+)\}Sequences/;
			var seqregex = /Sequences\{(.+)\}/;

			var stbmatch = stbregex.exec(result);
			var seqmatch = seqregex.exec(result);

			var members = stbmatch[1].split(',');
			var mstbcnt = '0';
			var mgrpcnt = '0';
			var missingstbs = '';
			var missinggroups = '';
			for (var i = 0; i < members.length; i++) {
				var bits = members[i].split("~");
				var id = bits[0];
				var text = bits[1];
				var regex = /^\s*\:\s*$|^\s*\-\s*$|^groupmissing/;    // If var text is like ':' or '-' it will be skipped from being added.
		                var match = regex.exec(text);
		                if (!match)  {
					seqTextUpdate(id,text);
				} else {
					if (id.match(/STB/i)) {
						missingstbs += id + ', ';
						mstbcnt++;
					} else if (text.match(/groupmissing/)) {
						missinggroups += id + ', ';
						mgrpcnt++;
					}
				}
			}

			missingstbs = missingstbs.replace(/,\s*$/,'');
			missinggroups = missinggroups.replace(/,\s*$/,'');

			if (missingstbs && missinggroups) {
				//alert('WARNING: A box that was included in this scheduled event has since been deconfigured or setup as a spacer. It will not be listed in the Target STB area below and will be removed from this Scheduled Event when you hit Update');
				alert("WARNING: " + mstbcnt + " STB(s) and " + mgrpcnt + " STB group(s) included in this scheduled event were not found in the data files. Please review the target STBs for this event\n\nMissing STBs:\n\n" + missingstbs + "\n\n\nMissing STB Groups:\n\n" + missinggroups);
			} else if (missingstbs) {
				alert("WARNING: " + mstbcnt + " STB(s) included in this scheduled event were not found in the data files. Please review the target STBs for this event\n\nMissing STBs:\n\n" + missingstbs);
			} else if (missinggroups) {
				alert("WARNING: " + mgrpcnt + " STB group(s) included in this scheduled event were not found in the data files. Please review the target STBs for this event\n\nMissing STB Groups:\n\n" + missinggroups);
			}

			var sequences = seqmatch[1].split(',');
			var missingseqs = '';
			var mseqscnt = '0';
			for (var i = 0; i < sequences.length; i++) {
				var bits = sequences[i].split("~");
                                var id = bits[0];
                                var text = bits[1];
				if (text.match(/^-$/)) {
					//alert('WARNING: A sequence that was included in this scheduled event could not be found. It may have been renamed or deleted. Please verify the sequences and update this scheduled event.');
					mseqscnt++;
					missingseqs += id + ', ';
				} else {
					//seqTextUpdate(id,text,'sequenceEventArea');
					schedSeqTextUpdate(id,text,'sequenceEventArea');
				}
			}

			missingseqs = missingseqs.replace(/,\s*$/,'');
			if (missingseqs) {
				alert("WARNING: " + mseqscnt + " sequence(s) included in this scheduled event were not found in the data files. Please review the sequence selection for this event\n\nMissing Sequences:\n\n" + missingseqs);
			}
		}
	});
}
// ############### End of editSchedulePage2 function


function stbTypeChoice($option) {	// This function handles changing of an STB type in the STB Data page. It loads the appropriate control data input fields according to its control type i.e. Dusky, Bluetooth, etc
	var tag = 'print' + $option;
	var stb = document.getElementById("stbname").value;
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
		if (!id.match(/^type$/)) {
			var first = $('#' + id + " option:first").val();
	        	$(this).val(first);
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

function ctrlSettings($opt) {
	if ($opt.match(/show/i)) {
		$('#controllerPageSettingsHolder').css('display','inline-block');
	} else {
		$('#controllerPageSettingsHolder').css('display','none');	
	}
}

function saveLayoutChoice() {
	var selected;
	$('.layoutRadio').each(function(i, obj) {
		if ($(this).is(':checked')) {
			//alert($(this).val());
			selected = $(this).val();
			return false;
		}
	});
	
	$.ajax({
		type : 'POST',
		url : 'cgi-bin/scripts/settings.pl',
		data : {
			'option' : 'savelayout',
			'data' : selected,
		},
		success : function(result) {
			if (result) {
				alert(result);
			}
		},
	});
}

function remoteChange($this) {
	var opt = $this.value;
	$.ajax({
		type : 'GET',
		url : 'cgi-bin/scripts/pages/remoteSelect.pl',
		data : {
			'remote' : opt,
		},
		success : function(result) {
			if (result) {
				$('#controllerButtons').html(result);
			}
		},
	});	
}

function seqRowHighlight($this) {
	var clicked = $($this).parent('.seqListRow');
	var classa = clicked.attr('class');
	if (classa.match(/focussed/)) {
		clicked.attr('class','seqListRow');
	} else {
		clicked.attr('class','seqListRow focussed');
	}
}

function evSchedRowHighlight($this) {
	var clicked = $($this);
	var classa = clicked.attr('class');
	if (classa.match(/focussed/)) {
		clicked.attr('class','evSchedRow');
	} else {
		clicked.attr('class','evSchedRow focussed');
	}
}
function groupRowHighlight($this) {
	var clicked = $($this);
	var classa = clicked.attr('class');
	if (classa.match(/focussed/)) {
		clicked.attr('class','groupListRow');
	} else {
		clicked.attr('class','groupListRow focussed');
	}
}

function rowRestrictionToggle($this) {
	var clicked = $($this);
	var classa = clicked.attr('class');
	var switc = 'on';
	if (classa.match(/on/)) {
		clicked.attr('class','rowRestrictSlider off');
		switc = 'off';
	} else {
		clicked.attr('class','rowRestrictSlider on');
	}

	$.ajax({
		type : 'POST',
		url : 'cgi-bin/scripts/settings.pl',
		data : {
			'option' : 'rowrestrict',
			'state' : switc,
		},
		success : function(result) {
			if (result) {
				if (result.match(/^ERROR/)) {
					alert(result);
					perlCall('dynamicPage','scripts/pages/settingsPage.pl');
				}
			}
		},
	});
}

function importStressScript() {
	var file = $('#real-input').val();
	var name = $('#importStressName').val();

	if (!file || !file.match(/\.txt$/)) {
		alert('You have not selected a valid .txt file. Please try again.');
		return;
	}

	if (!name || !name.match(/\S+/)) {
		var c = confirm('You have not provided a name or prefix, so the filename of the imported script will be used to name the sequence(s). Continue?');
		if (c == false) {
			return;
		}
	}

	var formData = new FormData();
	formData.append('file', $('#real-input')[0].files[0]);
	if (name) {
		formData.append('name', name);
	}
	formData.append('type','sequence');
	formData.append('format','stress');

	$.ajax({
		url: "cgi-bin/scripts/importData.pl",
		type: "POST",
		data: formData,
		enctype: 'multipart/form-data',
		processData: false,  // tell jQuery not to process the data
		contentType: false,   // tell jQuery not to set contentType
		success:function(result) {
			alert(result);
			if (result.match(/Success/i)) {
				$('#menuSequences').click();
			}
		}
	});
}

function importNativeScript() {
	var file = $('#real-input2').val();
	//var name = $('#importStressName2').val();

	if (!file || !file.match(/\.txt$|\.json$/i)) {
		alert('You have not selected a valid .txt file for native sequence import. Please try again.');
		return;
	}

	var formData = new FormData();
	formData.append('file', $('#real-input2')[0].files[0]);
	formData.append('type','sequence');
	formData.append('format','native');

	$.ajax({
		url: "cgi-bin/scripts/importData.pl",
		type: "POST",
		data: formData,
		enctype: 'multipart/form-data',
		processData: false,  // tell jQuery not to process the data
		contentType: false,   // tell jQuery not to set contentType
		success:function(result) {
			alert(result);
			if (result.match(/Success/i)) {
				$('#menuSequences').click();
			}
		}
	});
}

function expSeqSelect($id) {
	var checkstate = false;
	if ($id.match(/seqCheck-all-seqs/)) {
		if ($('#' + $id).is(":checked")) {
			checkstate = true;
		}
		
		$('.seqExpCheck').each(function() {
			if (!$(this).attr('id').match($id)) {
				$(this).prop('checked',checkstate);
			}
		});
	}
}

function seqStateChange($obj,$sequence) {
	var $class = $($obj).attr('class');
	var $state = 'active';
	if ($class.match(/active/)) {
		$($obj).attr('class','stateBox');
		$state = 'inactive';
	} else {
		$($obj).attr('class','stateBox active');
	}

	$.ajax({
		type : 'GET',
		url : 'cgi-bin/scripts/sequenceControl.pl',
		data : {
			'action' : 'StateChange',
			'sequence' : $sequence,
			'state' : $state
		},
		success : function(result) {
			if (!result.match(/Success/i)) {
				alert(result);
			}
		}
	});
}

function logSeqCaratPos() {
	seqpos = $('#sequenceArea').caret('position');
	console.log('New caret position at ' + seqpos.left + ' - ' + seqpos.top);
	seqpos2 = document.getSelection().anchorNode;
}

//var schedseqpos; <----- Global var set at top of page
//var schedseqrange; <----- Global var set at top of page
// This function handles the first part of adding sequences in to the dynamic sequenceEventArea areas on the Events Schedule creation and editing pages
function schedSeqTextUpdate($id,$text,$area) {
	if (!$area) {
		$area = 'sequenceEventArea';
	}

	var btn = document.createElement("input");
	btn.type = 'button';
	btn.value = $text;
	var newid = $id + '-' + sequenceIndex;
	btn.id = newid
	btn.name = $id;
	sequenceIndex++;
	var newonclick = "removeFromSchedSeq('" + newid + "','" + $area + "')";
	btn.setAttribute("class", "seqAreaBtn");
	btn.setAttribute("onclick", newonclick);
	insertButtonAtCaretSchedSeq(btn,$area);
}
// ############### End of schedSeqTextUpdate function

// This function handles the second part of adding STBs and Commands in to the dynamic areas on the Events Schedule creation and editing pages
function insertButtonAtCaretSchedSeq($btn,$area) {
	if (!$area) {
		$area = 'sequenceEventArea';
	}

    	$('#' + $area).focus();
    	var sel;
    	if (window.getSelection) {
		// IE9 and non-IE
		sel = window.getSelection();
		if (!schedseqrange){
        		if (sel.getRangeAt && sel.rangeCount) {
            			schedseqrange = sel.getRangeAt(0);
            			schedseqrange.deleteContents();
			}
		} else {
			if (schedseqpos){
				schedseqrange.setStartAfter(schedseqpos);
			}
		}
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

		schedseqrange.insertNode(frag);

    		// Preserve the selection
    		if (lastNode) {
        		schedseqrange = schedseqrange.cloneRange();
        		schedseqrange.setStartAfter(lastNode);
        		schedseqpos = lastNode;
			schedseqrange.collapse(true);
        		sel.removeAllRanges();
        		sel.addRange(schedseqrange);
    		}
    	} else if (document.selection && document.selection.type != "Control") {
        	// IE < 9
        	document.selection.createRange().appendChild($btn);
    	}
}
// ############### End of insertButtonAtCaretSchedSeq function

function logSchedSeqCaratPos() {
	schedseqcarpos = $('#sequenceEventArea').caret('position');
	console.log('New caret position at ' + schedseqcarpos.left + ' - ' + schedseqcarpos.top);
	schedseqpos = document.getSelection().anchorNode;
}

// This function handles removing specific elements from the dynamic sequence area on the creation and editing pages of the Events Schedule
function removeFromSchedSeq($this,$area) {
	var rem = document.getElementById($this);
	if (!$area) {
		$area = 'sequenceEventArea';
	}

	document.getElementById($area).removeChild(rem);

	if (isFirefox) {
                var data = document.getElementById($area).innerHTML;
                var newdata = data.replace(/(?:\&nbsp;){3,}/g, "\&nbsp\;\&nbsp\;");
                document.getElementById($area).innerHTML = newdata;
        }

	// ##### Once you remove a child node from the sequenceEventArea, we need to locate the last child node in that div
	// ##### If there aren't any (sequenceEventArea is empty), reset the last node variable "schedseqpos" to null
	var ln = document.getElementById('sequenceEventArea').lastChild;
	if (ln) {
		schedseqpos = ln;
	} else {
		schedseqpos = '';
	}
}
// ############### End of removeFromSchedSeq function

// This function handles clearing of the dynamic areas on the creation and editing pages for the Events Schedule
function clearSchedSeqArea($area) {
	document.getElementById($area).innerHTML = '';
	schedseqpos = '';
}
// ############### End of clearSchedSeqArea function

function gridModeSwitch($this) {
	var $selectid = $($this).attr('id');
	//var $mode = 'stbgrid';
	if ($selectid.match(/group/i)) {
		$('#gridModeSTBs').attr('class','gridModeDiv');
		gridcontmode = 'stbgroups';
		logLastBoxes();
	} else {
		$('#gridModeGroups').attr('class','gridModeDiv');
		gridcontmode = 'stbgrid';
	}
	$($this).attr('class','gridModeDiv selected');

	$.ajax({
		type : 'GET',
		url : 'cgi-bin/scripts/pages/stbGrid.pl',
		data : {
			'mode' : gridcontmode
		},
		success : function(result) {
			if (result) {
				result = result.replace(/<div id=\"stbGrid\" class=\"controllerPageSection\">/,'');
				result = result.replace(/\<\/div\>$/,'');
				$('#stbGrid').html(result);
				if (gridcontmode.match(/stbgroups/)) {
					if (lastgroupselected) {
						$('#' + lastgroupselected).click();
						$('#groupControlListHolder').animate({
						        scrollTop: $('#groupControlListHolder #' + lastgroupselected).position().top
						}, 'slow');
					}
				} else if (gridcontmode.match(/stbgrid/)) {
					getLastBoxes();
				}
			}
		}
	});

}

function groupSTBControl($this) {
	var selectedid = $($this).attr('id');
	var groupname = $($this).find('.groupControlRowSection:first').text();
	$($this).attr('class','groupSTBControlRow selected');
	var regexp = new RegExp(selectedid);
	$('.groupSTBControlRow').each(function(index) {
		if ( !$(this).attr('id').match(regexp) ) {
			$(this).attr('class','groupSTBControlRow');
		}
	});
	lastgroupselected = selectedid;		// Log this group as the last selected group for navigation purposes


}
// end hiding script from old browsers -->
