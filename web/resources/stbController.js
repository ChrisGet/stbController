<!-- hide script from old browsers

window.onload = function () {
	dateTime();
}

window.onunload = window.onbeforeunload = function ()  {
logLastBoxes();
}

$.ajaxSetup({ cache: false });

var stbHash = {};	// Create the stbHash object to handle selected STBs from the grid
var lastRow;		// Create the lastRow variable to be manipulated elsewhere
var lastRowHL;		// Create the lastRowHL variable to record last highlighted row

function dateTime() {
	setInterval(function() {
		var div = document.getElementById('dateTimeDiv');
		if (div) {
			var date = new Date();
			var hour = ('0' + date.getHours()).slice(-2);
			var min = ('0' + date.getMinutes()).slice(-2);
			var secs = ('0' + date.getSeconds()).slice(-2);
			var time = hour + ':' + min + ':' + secs;
			document.getElementById('dateTimeDiv').innerHTML = time + ' - ' + date.toDateString();
		}
	},1000);
}

function stbControl($action,$commands) {
	var comstring = '';
	for (var key in stbHash) {
		comstring += key + ',';
	}

	// Validate whether any STBs have been selected for control. Return if none have
	if (!comstring) {
		alert('No valid STBs have been selected for control');
		return;
	}

	perlCall('','scripts/stbControl.pl','action',$action,'command',$commands,'info',comstring);
}

function perlCall ($element, $script, $param1, $value1, $param2, $value2, $param3, $value3, $param4, $value4) {
	var regex = /\S+/;
	var elemmatch = regex.exec($element);
	var xmlhttp;
	if (window.XMLHttpRequest){
		xmlhttp=new XMLHttpRequest();
	} else {
		xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
	}

	xmlhttp.onreadystatechange=function(){
		if (xmlhttp.readyState==4) {
			if (elemmatch) {
				document.getElementById($element).innerHTML=xmlhttp.responseText;
			}
		}
	}

	xmlhttp.open("GET","cgi-bin/" + $script +"?"+$param1 + "=" + $value1 + "&"+$param2+"="+$value2 + "&"+$param3+"="+$value3 + "&"+$param4+"="+$value4,true);
	xmlhttp.send();
}
// ############### End of perlCall function

function pageCall ($element, $page) {
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

	xmlhttp.open("GET",$page);
	xmlhttp.send();
}
// ############### End of pageCall function

function getLastBoxes() {
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

function getLastBoxesAlternative() {	// Not in use but handy to keep available if needed
	var xmlhttp;
if (window.XMLHttpRequest)
  {// code for IE7+, Firefox, Chrome, Opera, Safari
  xmlhttp=new XMLHttpRequest();
  }
else
  {// code for IE6, IE5
  xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
  }
xmlhttp.onreadystatechange=function()
  {
  if (xmlhttp.readyState==4)
    {
    //document.getElementById("").innerHTML=xmlhttp.responseText;
    }
}
	var date = Date();
	xmlhttp.open("GET","web/lastBoxes.txt?date", false);
	xmlhttp.setRequestHeader("User-Agent",navigator.userAgent);
	xmlhttp.send(null);
	var returned = xmlhttp.responseText;
	var boxes = returned.split(",");
	var arrayLength = boxes.length;
	stbHash = {};
	for (var i=0;i<arrayLength;i++) {
		var stb = boxes[i];
		colorToggle(stb,'selected');
	}		
}

function logLastBoxes() {
	var comstring = '';
        for (var key in stbHash) {
                comstring += key + ',';
        }
	localStorage && (localStorage.lastBoxes = comstring);
}

function logLastBoxesAlternative() {	// Not in use but handy to keep available if needed
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

	var comstring = '';
        for (var key in stbHash) {
                comstring += key + ',';
        }

	perlCall('','scripts/logLastBoxes.pl','boxes',comstring);
}

function validate() 
{
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
	perlCall('dynamicPage','scripts/controllerConfig.pl');
	return false;
}
// ############### End of validate function

function editSTBData($name) {
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

function deselect() {
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

function colorToggle($id,$override,$highlight){
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

var highlightedSTBs = {};

function rows($row) {
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

	for(var i=0;i<count;i++) {					// While 'i' is less than the number of cells
		var cell = row.getElementsByTagName("button")[i];	// Locate the button in that cell and save it in 'cell'
		if (!cell) {
			continue;			// Skip the cell if it has no button (STB has been given ':' as its name and is therefore blank)
		}
		var ayedee = cell.id;					// Get the buttons id and save it to 'ayedee'
		var regex = /^Row.*/;
		var match = regex.exec(ayedee);
		if (match) {
			continue;			// Skip the row button that is in that row
		}
		colorToggle(ayedee,override,highlight);					// Send 'ayedee' to the colorToggle function
	}
}
// ############### End of rows function

function arrowDir($opt) {
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


var sequenceIndex = '1';

function seqTextUpdate($id,$text) {
	var btn = document.createElement("input");
	btn.type = 'button';
	btn.value = $text;
	var newid = $id + '-' + sequenceIndex;
	btn.id = newid
	btn.name = $id; 
	sequenceIndex++;
	var newonclick = "removeFromSeq('" + newid + "')";
	btn.setAttribute("class", "seqAreaBtn");
	btn.setAttribute("onclick", newonclick);
	insertButtonAtCaret(btn);
}

function clearSeqArea() {
	document.getElementById('sequenceArea').innerHTML = '';
	sequenceIndex = '1';
}

function removeFromSeq($this) {
	var rem = document.getElementById($this);
	document.getElementById('sequenceArea').removeChild(rem);
}

function insertButtonAtCaret($btn) {
    $('#sequenceArea').focus();
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
            el.appendChild($btn);
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

function addSeqTO() {
	var timeout = document.getElementById('timeoutList').value;
	var id = 't' + timeout;
	var text = 'Timeout (' + timeout + 's)';
	seqTextUpdate(id,text);
}

function addSeqGroup() {
	var group = document.getElementById('groupList').value;
	if(!group) {
		return;
	}
	seqTextUpdate(group,group);
}

function seqValidate($origname) {
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
						xmlhttp.onreadystatechange=function() {
			  				if (xmlhttp.readyState==4) {
								//document.getElementById("").innerHTML=xmlhttp.responseText;
							}
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
					xmlhttp.onreadystatechange=function() {
	  					if (xmlhttp.readyState==4) {
							//document.getElementById("").innerHTML=xmlhttp.responseText;
						}
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

function deleteSequence($seq) {
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

function editSequencePage($seq) {
	perlCall('dynamicPage','scripts/pages/sequencesPage.pl','action','Edit','sequence',$seq);
	setTimeout(function(){editSequencePage2($seq)},200);
}

function editSequencePage2($seq) {
	var xmlhttp;
        if (window.XMLHttpRequest) {// code for IE7+, Firefox, Chrome, Opera, Safari
        	xmlhttp=new XMLHttpRequest();
      	} else {// code for IE6, IE5
        	xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
      	}
       	xmlhttp.onreadystatechange=function() {
        	if (xmlhttp.readyState==4) {
        	}
       	}

      	xmlhttp.open("GET","cgi-bin/scripts/sequenceControl.pl?action=Show&sequence=" + $seq, false);
    	xmlhttp.send(null);
     	var returned = xmlhttp.responseText;
	var commands = returned.split(',');
	for (var i = 0; i < commands.length; i++) {
		var id = commands[i];
		var text = id;
		if (id == 'tv guide') {
			text = 'TV Guide';
		}
		if (id == 'passive') {
			text = 'Deep Sleep';
		}
		var bits = text.split(" ");
		var newtext = '';
		for (var o = 0; o < bits.length; o++) {
			var chunk = bits[o];
			//alert('Chunk = ' + chunk);
			newtext += chunk[0].toUpperCase() + chunk.slice(1);
			newtext += ' ';
		}
		seqTextUpdate(id,newtext);
	}	
}

function groupValidate($origname) {
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
						xmlhttp.onreadystatechange=function() {
	  						if (xmlhttp.readyState==4) {
								//document.getElementById("").innerHTML=xmlhttp.responseText;
							}
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
					xmlhttp.onreadystatechange=function() {
	  					if (xmlhttp.readyState==4) {
							//document.getElementById("").innerHTML=xmlhttp.responseText;
						}
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

function deleteGroup($grp) {
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

function editGroupPage($grp) {
	perlCall('dynamicPage','scripts/pages/stbGroupsPage.pl','action','Edit','group',$grp);
	setTimeout(function(){editGroupPage2($grp)},500);
}

function editGroupPage2($grp) {
	var xmlhttp;
        if (window.XMLHttpRequest) {// code for IE7+, Firefox, Chrome, Opera, Safari
        	xmlhttp=new XMLHttpRequest();
      	} else {// code for IE6, IE5
        	xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
      	}
       	xmlhttp.onreadystatechange=function() {
        	if (xmlhttp.readyState==4) {
        	}
       	}

      	xmlhttp.open("GET","cgi-bin/scripts/stbGroupControl.pl?action=Show&group=" + $grp, false);
    	xmlhttp.send(null);
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

function tooltip() {
	$(document).ready(function() {
	// Tooltip only Text
	$('.masterTooltip').hover(function(){
	        // Hover over code
	        var title = $(this).attr('value');
	        $('<p class="tooltip"></p>')
	        .text(title)
	        .appendTo('body')
	        .fadeIn('fast');
	}, function() {
        	// Hover out code
	        $('.tooltip').remove();
	}).mousemove(function(e) {
	        var mousex = e.pageX + 20; //Get X coordinates
	        var mousey = e.pageY + 10; //Get Y coordinates
	        $('.tooltip')
	        .css({ top: mousey, left: mousex })
		});
	});
}

function focusEl($element) {
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

	//This stuff below runs the tooltip function when the Sequences or STB Groups page is loaded and focussed.
	//This allows the hover functions to bind to the elements so that first time hover works properly
	if ($element == 'sequencesAvailable') {
		setTimeout(function(){tooltip()},200);
	}
	if ($element == 'stbGroupsAvailable') {
		setTimeout(function(){tooltip()},200);
	}
}

function bindTrigger() {
	$(".trigger").change(function() {
		if($(this).is(":checked")) {
			$('input[type=radio]').each(function(){
				$(this).attr('class','trigger radiooff');
			});
			$(this).attr('class','trigger radioon');
		}
	});
}

function newSchedValidate($event) {
	var elements = document.getElementById('sequenceArea').getElementsByTagName('input');
	var members = [];
	for (var i = 0; i < elements.length; i++) {
		members.push(elements[i].name);
	}
	if (!members[0]) {
		alert('You have not selected any target STBs for this scheduled event!');
	} else {
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

		var seqsel = $('#seqList').val();
		if (!seqsel) {
			alert('Sequence selection cannot be blank!');
			return;
		}

		var mins = $('#minutes').val();
		var hours = $('#hours').val();
		var dom = $('#dom').val();
		var month = $('#month').val();
		var sequence = $('#seqList').val();
		var boxes = members.join(',');
		var wholething = mins + '|' + hours + '|' + dom + '|' + month + '|' + days + '|' + sequence + '|' + boxes;
		
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
}

function deleteSchedule($id) {
	var c = confirm('Are you sure you want to delete this scheduled event?');
	if (c == false) {
       		return;
	}
	perlCall('','scripts/eventScheduleControl.pl','action','Delete','eventID',$id);
	setTimeout(function(){perlCall('evSchedsAvailable','scripts/pages/eventSchedulePage.pl','action','Menu')},200);
}

function scheduleStateChange($state,$id) {
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

function editSchedulePage($event) {
	perlCall('dynamicPage','scripts/pages/eventSchedulePage.pl','action','Edit','event',$event);
	setTimeout(function(){editSchedulePage2($event)},500);
}

function editSchedulePage2($event) {
	var xmlhttp;
        if (window.XMLHttpRequest) {// code for IE7+, Firefox, Chrome, Opera, Safari
        	xmlhttp=new XMLHttpRequest();
      	} else {// code for IE6, IE5
        	xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
      	}
       	xmlhttp.onreadystatechange=function() {
        	if (xmlhttp.readyState==4) {
        	}
       	}

      	xmlhttp.open("GET","cgi-bin/scripts/eventScheduleControl.pl?action=Show&eventID=" + $event, false);
    	xmlhttp.send(null);
     	var returned = xmlhttp.responseText;
	var members = returned.split(',');
	for (var i = 0; i < members.length; i++) {
		var bits = members[i].split("~");
		var id = bits[0];
		var text = bits[1];
		var regex = /^\s*\:\s*$|^\s*\-\s*$/;    // If var text is like ':' or '-' it will be skipped from being added.
                var match = regex.exec(text);
                if (!match)  {
			seqTextUpdate(id,text);
		} else {
			alert('A box that was included in this scheduled event has since been deconfigured or setup as a spacer. It will not be listed in the Target STB area below and will be removed from this Scheduled Event when you hit Update');
		}
	}	
}


function stbTypeChoice($option) {
	var tag = 'print' + $option;
	perlCall('typeChange','scripts/pages/stbDataPage.pl','option',tag);
}

function daysSelectedCheck() {
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

// end hiding script from old browsers -->
