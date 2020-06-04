/*

Custom Post-Processor for GRBL based Openbuilds-style CNC machines
Using Exiting Post Processors as inspiration
For documentation, see GitHub Wiki : https://github.com/Strooom/GRBL-Post-Processor/wiki
This post-Processor should work on GRBL-based machines such as
* Openbuilds - OX, C-Beam, Workbee, LEAD and other GRBL based mills
* Inventables - X-Carve
* ShapeOko / Carbide3D
* your spindle is Makita RT0700 or Dewalt 611

22/AUG/2016 - V1 : Kick Off
23/AUG/2016 - V2 : Added Machining Time to Operations overview at file header
24/AUG/2016 - V3 : Added extra user properties - further cleanup of unused variables
07/SEP/2016 - V4 : Added support for INCHES. Added a safe retract at beginning of first section
11/OCT/2016 - V5
30/JAN/2017 - V6 : Modified capabilities to also allow waterjet, laser-cutting..
28 Jan 2018 - V7 : swarfered to fix arc errors and add gotoMCSatend option
16 Feb 2019 - V8 : swarfer , ensure X, Y, Z  output when linear differences are very small
27 Feb 2019 - V9 : swarfer : found out the correct way to force word output for XYZIJK, see 'force:true' in CreateVariable
27 Feb 2018 - V10 : from sharmstr : Added user properties for router type. Added rounding of dial settings to 1 decimal.
16 Mar 2019 - V11 : from sharmstr : Added rounding of tool length to 2 decimals.  Added check for machine config in setup. 
										Changed RPM warning so it includes operation. Added multiple .nc file generation for tool changes.
										Added check for duplicate tool numbers with different geometry.
17 Apr 2019 - V12 : from sharmstr - Added check for minimum  feed rate.  Added file names to header when multiple are generated
										Added a descriptive title to gotoMCSatend to better explain what it does. Moved machine vendor, model and control to user properties

15 Aug 2019 - V13 : from sharmstr - Grouped properties for clarity
*/

description = "Openbuilds Grbl V13 Blackbox,xPro";
vendor = "Openbuilds and the Swarfer";
vendorUrl = "http://openbuilds.com";
model = "GRBL";
description = "Swarfer Grbl Post"; // or something else to make it more descriptive
legal = "Copyright (C) 2012-2019 by Autodesk, Inc.";
certificationLevel = 2;

extension = "nc";										// file extension of the gcode file
setCodePage("ascii");									// character set of the gcode file
//setEOL(CRLF);											// end-of-line type : use CRLF for windows

capabilities = CAPABILITY_MILLING | CAPABILITY_JET;		// intended for a CNC, so Milling, and waterjet/plasma/laser
tolerance = spatial(0.01, MM);
minimumChordLength = spatial(0.25, MM);
minimumCircularRadius = spatial(0.125, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.1); // was 0.01
maximumCircularSweep = toRad(180);
allowHelicalMoves = true;
allowedCircularPlanes = (1 << PLANE_XY);// | (1 << PLANE_ZX) | (1 << PLANE_YZ); // only XY, ZX, and YZ planes
// the above circular plane limitation appears to be a solution to the faulty arcs problem (but is not entirely)
// an alternative is to set EITHER minimumChordLength OR minimumCircularRadius to a much larger value, like 0.5mm

var GRBLunits = MM;										// GRBL controller set to mm (Metric). Allows for a consistency check between GRBL settings and CAM file output
// var GRBLunits = IN;

// user-defined properties : defaults are set, but they can be changed from a dialog box in Fusion when doing a post.
properties =
	{
	spindleOnOffDelay: 1.8,				// time (in seconds) the spindle needs to get up to speed or stop
	spindleTwoDirections : false,		// true : spindle can rotate clockwise and counterclockwise, will send M3 and M4. false : spindle can only go clockwise, will only send M3
	hasCoolant : false,					// true : machine uses the coolant output, M8 M9 will be sent. false : coolant output not connected, so no M8 M9 will be sent
	routerType : "Other",	
	speedDial: false, // true : the spindle is of type Makite RT0700, Dewalt 611 with a Dial to set speeds 1-6. false : other spindle
	generateMultiple: true,          // specifies if a file should be generated for each tool change
	machineHomeZ : -10,					// absolute machine coordinates where the machine will move to at the end of the job - first retracting Z, then moving home X Y
	machineHomeX : -10,
	machineHomeY : -10,
   gotoMCSatend : false,            // true will do G53 G0 x{machinehomeX} y{machinehomeY}, false will do G0 x{machinehomeX} y{machinehomeY} at end of program
 	machineVendor : "OpenBuilds",
	machineModel : "OX,Workbee,Sphinx,Lead",
	machineControl : "BlackBox GRBL V1.1",
	_Section1: "******",    // used to break up properties into sections for clarity
	_Section2: "******",
  _Section3: "******",
  _Section4: "******"                             
};  
// user-defined property definitions
propertyDefinitions = {
	_Section1: {
		title:"--- MACHINE INFO ---",
		description:"Informational only. Not used for any computation.",
		type:"string",
		group: 1
	},
	machineVendor: {
		title:"Machine Vendor", 
		description: "Machine vendor defined here will be displayed in header if machine config not set.",
		type:"string",
		group: 1
	},
	machineModel: {
		title:"Machine Model", 
		description: "Machine model defined here will be displayed in header if machine config not set.",
		type:"string",
		group: 1
	},
	machineControl: {
		title:"Machine Control", 
		description: "Machine control defined here will be displayed in header if machine config not set.",
		type:"string",
		group: 1
  },
  _Section2: {
		title:"--- SPINDLE INFO ---",
		description:"Informational only. Not used for any computation.",
		type:"string",
		group: 2
	},
	routerType:  {
		title: "Spindle/Router type",
		description: "Select the type of spindle you have.",
		type: "enum",
      group: 2,     
		values:[
		  {title:"Other", id:"other"},
		  {title:"Makita RT0700", id:"Makita"},
		  {title:"Dewalt 611", id:"Dewalt"}
		]
	},
	speedDial:  {
		title: "Has Speed Dial",
		description: "Does your router have a speed dial?",
		type: "boolean",
		group: 2
  },
  spindleTwoDirections:  {
		title: "Spindle can rotate clockwise and counterclockwise?",
		description:  "Yes : spindle can rotate clockwise and counterclockwise, will send M3 and M4. No : spindle can only go clockwise, will only send M3",
		type: "boolean",
		group: 2
  },
  spindleOnOffDelay:  {
  	title: "Spindle on/off delay",
  	description: "Time (in seconds) the spindle needs to get up to speed or stop",
  	type: "number",
  	group: 2
  },
  hasCoolant:  {
  	title: "Has coolant?",
    description: "Yes: machine uses the coolant output, M8 M9 will be sent. No : coolant output not connected, so no M8 M9 will be sent",
    type: "boolean",
    group: 3
   },      
  _Section3: {
		title:"--- TOOL CHANGE HANDLING ---",
		description:"Informational only. Not used for any computation.",
		type:"string",
		group: 4
	},    
	generateMultiple: {
		title:"Generate muliple files for tool changes?", 
		description: "Generate multiple files. One for each tool change.", 
		type:"boolean",
		group: 4
  },
  _Section4: {
		title:"--- END OF JOB COORDIATES ---",
		description:"Informational only. Not used for any computation.",
		type:"string",
		group: 5
	},
	gotoMCSatend: {
		title:"Use Machine Coordinates (G53) at end of job?", 
		description: "Yes will do G53 G0 x{machinehomeX} y(machinehomeY) (Machine Coordinates), No will do G0 x(machinehomeX) y(machinehomeY) (Work Coordinates) at end of program",
		type:"boolean",
		group: 5
	},
	machineHomeX: {
		title:"End of job X position.", 
		description: "(G53 or G54) X position to move to",
		type:"number",
		group: 6
	},
	machineHomeY: {
		title:"End of job Y position.", 
		description: "(G53 or G54) Y position to move to.",
		type:"number",
		group: 6
	},
	machineHomeZ: {
		title:"End of job Z position (MCS Only)", 
		description: "G53 Z position to move to.",
		type:"number",
		group: 6
	}
};

// creation of all kinds of G-code formats - controls the amount of decimals used in the generated G-Code
var gFormat = createFormat({prefix:"G", decimals:0});
var mFormat = createFormat({prefix:"M", decimals:0});

var xyzFormat = createFormat({decimals:(unit == MM ? 3 : 4)});
var abcFormat = createFormat({decimals:3, forceDecimal:true, scale:DEG});
var arcFormat = createFormat({decimals:(unit == MM ? 3 : 4)});    // uses extra digit in arcs - not always effective, just set them the same
var feedFormat = createFormat({decimals:0});
var rpmFormat = createFormat({decimals:0});
var secFormat = createFormat({decimals:1, forceDecimal:true});
var taperFormat = createFormat({decimals:1, scale:DEG});

var xOutput = createVariable({prefix:"X", force:true}, xyzFormat);
var yOutput = createVariable({prefix:"Y", force:true}, xyzFormat);
var zOutput = createVariable({prefix:"Z", force:false}, xyzFormat); // dont need Z every time
var feedOutput = createVariable({prefix:"F"}, feedFormat);
var sOutput = createVariable({prefix:"S", force:true}, rpmFormat);

// for arcs, use extra digit (not used anymore from jan 2018)
var xaOutput = createVariable({prefix:"X", force:true}, arcFormat);
var yaOutput = createVariable({prefix:"Y", force:true}, arcFormat);
var zaOutput = createVariable({prefix:"Z", force:true}, arcFormat);

var iOutput = createReferenceVariable({prefix:"I", force:true}, arcFormat);
var jOutput = createReferenceVariable({prefix:"J", force:true}, arcFormat);
var kOutput = createReferenceVariable({prefix:"K", force:true}, arcFormat);

var gMotionModal = createModal({}, gFormat); 											// modal group 1 // G0-G3, ...
var gPlaneModal = createModal({onchange:function () {gMotionModal.reset();}}, gFormat); // modal group 2 // G17-19
var gAbsIncModal = createModal({}, gFormat); 											// modal group 3 // G90-91
var gFeedModeModal = createModal({}, gFormat); 											// modal group 5 // G93-94
var gUnitModal = createModal({}, gFormat); 												// modal group 6 // G20-21

var sequenceNumber = 1;        //used for multiple file naming
var multipleToolError = false; //used for alerting during single file generation with multiple tools
var filesToGenerate = 1;       //used to figure out how many files will be generated so we can diplay in header
var minimumFeedRate = 45;
var fileIndexFormat = createFormat({width:2, zeropad: true, decimals:0});
function toTitleCase(str)
	{
	// function to reformat a string to 'title case'
	return str.replace(/\w\S*/g, function(txt)
		{
		return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
		});
	}

function rpm2dial(rpm, op)
	{
	// translates an RPM for the spindle into a dial value, eg. for the Makita RT0700 and Dewalt 611 routers
	// additionally, check that spindle rpm is between minimum and maximum of what our spindle can do
	// array which maps spindle speeds to router dial settings,
	// according to Makita RT0700 Manual : 1=10000, 2=12000, 3=17000, 4=22000, 5=27000, 6=30000
	// according to Dewalt 611 Manual : 1=16000, 2=18200, 3=20400, 4=22600, 5=24800, 6=27000
	
	if (properties.routerType == "Dewalt"){
		var speeds = [0, 16000, 18200, 20400, 22600, 24800, 27000];
	} else {
		var speeds = [0, 10000, 12000, 17000, 22000, 27000, 30000];
	}
	if (rpm < speeds[1])
		{
		alert("Warning", rpm + " rpm is below minimum spindle RPM of " + speeds[1] + " rpm in the " + op + " operation.");
		return 1;
		}

	if (rpm > speeds[speeds.length - 1])
		{
		alert("Warning", rpm + " rpm is above maximum spindle RPM of " + speeds[speeds.length - 1] + " rpm in the " + op + " operation.");
		return (speeds.length - 1);
		}

	var i;
	for (i=1; i < (speeds.length-1); i++)
		{
		if ((rpm >= speeds[i]) && (rpm <= speeds[i+1]))
			{
			return (((rpm - speeds[i]) / (speeds[i+1] - speeds[i])) + i).toFixed(1);
			}
		}

	alert("Error", "Error in calculating router speed dial..");
	error("Fatal Error calculating router speed dial");
	return 0;
	}

function checkMinFeedrate(section, op) 
{
	var alertMsg = "";
	if(section.getParameter("operation:tool_feedCutting") < minimumFeedRate)
	{		
		var alertMsg = "Cutting\n";
		//alert("Warning", "The cutting feedrate in " + op + "  is set below the minimum feedrate that grbl supports.");
	}

	if(section.getParameter("operation:tool_feedRetract") < minimumFeedRate)
	{		
		var alertMsg = alertMsg + "Retract\n";
		//alert("Warning", "The retract feedrate in " + op + "  is set below the minimum feedrate that grbl supports.");
	}

	if(section.getParameter("operation:tool_feedEntry") < minimumFeedRate)
	{		
		var alertMsg = alertMsg + "Entry\n";
		//alert("Warning", "The retract feedrate in " + op + "  is set below the minimum feedrate that grbl supports.");
	}

	if(section.getParameter("operation:tool_feedExit") < minimumFeedRate)
	{		
		var alertMsg = alertMsg + "Exit\n";
		//alert("Warning", "The retract feedrate in " + op + "  is set below the minimum feedrate that grbl supports.");
	}

	if(section.getParameter("operation:tool_feedRamp") < minimumFeedRate)
	{		
		var alertMsg = alertMsg + "Ramp\n";
		//alert("Warning", "The retract feedrate in " + op + "  is set below the minimum feedrate that grbl supports.");
	}

	if(section.getParameter("operation:tool_feedPlunge") < minimumFeedRate)
	{		
		var alertMsg = alertMsg + "Plunge\n";
		//alert("Warning", "The retract feedrate in " + op + "  is set below the minimum feedrate that grbl supports.");
	}
		
	if (alertMsg != "")
	{
		alert("Warning", "The following feedrates in " + op + "  are set below the minimum feedrate that grbl supports.  The feedrate should be higher than " + minimumFeedRate + "mm per min.\n\n" + alertMsg);
	}		
}	
function writeBlock()
	{
	writeWords(arguments);
	}

/**
Thanks to nyccnc.com
Thanks to the Autodesk Knowledge Network for help with this at https://knowledge.autodesk.com/support/hsm/learn-explore/caas/sfdcarticles/sfdcarticles/How-to-use-Manual-NC-options-to-manually-add-code-with-Fusion-360-HSM-CAM.html! 
*/   
function onPassThrough(text) {
  var commands = String(text).split(",");
  for (text in commands) {
    writeBlock(commands[text]);
  }
}

function myMachineConfig() {
	// 3. here you can set all the properties of your machine if you havent set up a machine config in CAM.  These are optional and only used to print in the header.
	myMachine = getMachineConfiguration();
	if (!myMachine.getVendor()) {
		// machine config not found so we'll use the info below
		myMachine.setWidth(600);
		myMachine.setDepth(800);
		myMachine.setHeight(130);
		myMachine.setMaximumSpindlePower(700);
		myMachine.setMaximumSpindleSpeed(30000);
		myMachine.setMilling(true);
		myMachine.setTurning(false);
		myMachine.setToolChanger(false);
		myMachine.setNumberOfTools(1);
		myMachine.setNumberOfWorkOffsets(6);
		myMachine.setVendor(properties.machineVendor);
		myMachine.setModel(properties.machineModel);
		myMachine.setControl(properties.machineControl);
	}
}

function writeComment(text)
	{
	// Remove special characters which could confuse GRBL : $, !, ~, ?, (, )
	// In order to make it simple, I replace everything which is not A-Z, 0-9, space, : , .
	// Finally put everything between () as this is the way GRBL & UGCS expect comments
	writeln("(" + String(text).replace(/[^a-zA-Z\d :=,.]+/g, " ") + ")");
	}

   
function writeHeader(secID) 
{
	if (multipleToolError)
      {
      writeComment("Warning: Multiple tools found.  This post does not support tool changes.  You should repost and select True for Multiple Files in the post properties.");
      writeln("");
      }
    
   var productName = getProduct();
	writeComment("Made in : " + productName);
	writeComment("G-Code optimized for " + myMachine.getVendor() + " " + myMachine.getModel() + " with " + myMachine.getControl() + " controller");

	writeln("");

	if (programName) {
		writeComment("Program Name : " + programName);
	}
	if (programComment) {
		writeComment("Program Comments : " + programComment);
    }
    writeln("");

    if (properties.generateMultiple) {
        writeComment(numberOfSections + " Operation" + ((numberOfSections == 1) ? "" : "s") + " in "+ filesToGenerate + " files.");
				writeComment("File List:");
				writeComment("  " +  FileSystem.getFilename(getOutputPath()));
				for (var i = 0; i < filesToGenerate-1; ++i) {
						filenamePath = FileSystem.replaceExtension(getOutputPath(), fileIndexFormat.format(i+2) + "of" + filesToGenerate + ".nc");
						filename = FileSystem.getFilename(filenamePath);
						writeComment("  " + filename);
				}
				writeln("");
        writeComment("This is file: " + sequenceNumber + " of " + filesToGenerate);
        writeln("");
        writeComment("This file contains the following operations: ");
    } else {
        writeComment(numberOfSections + " Operation" + ((numberOfSections == 1)?"":"s") + " :");
    }
    
	for (var i = secID; i < numberOfSections; ++i) {
		var section = getSection(i);
		var tool = section.getTool();
		var rpm = section.getMaximumSpindleSpeed();
		if (section.hasParameter("operation-comment")) {
			writeComment((i+1) + " : " + section.getParameter("operation-comment"));
			var op = section.getParameter("operation-comment")
		}
		else {
			writeComment(i + 1);
			var op = i + 1;
		}
		if (section.workOffset > 0) {
			writeComment("  Work Coordinate System : G" + (section.workOffset + 53));
		}
		writeComment("  Tool #" + tool.number + ": " + toTitleCase(getToolTypeName(tool.type)) + " " + tool.numberOfFlutes + " Flutes, Diam = " + xyzFormat.format(tool.diameter) + "mm, Len = " + tool.fluteLength.toFixed(2) + "mm");
		if (properties.speedDial) {
			writeComment("  Spindle : RPM = " + rpm + ", set router dial to " + rpm2dial(rpm, op));
		} else {
			writeComment("  Spindle : RPM = " + rpm);
		}
		checkMinFeedrate(section, op);
		var machineTimeInSeconds = section.getCycleTime();
		var machineTimeHours = Math.floor(machineTimeInSeconds / 3600);
		machineTimeInSeconds = machineTimeInSeconds % 3600;
		var machineTimeMinutes = Math.floor(machineTimeInSeconds / 60);
		var machineTimeSeconds = Math.floor(machineTimeInSeconds % 60);
		var machineTimeText = "  Machining time : ";
		if (machineTimeHours > 0) {
			machineTimeText = machineTimeText + machineTimeHours + " hours " + machineTimeMinutes + " min ";
		}
		else if (machineTimeMinutes > 0) {
			machineTimeText = machineTimeText + machineTimeMinutes + " min ";
		}
		machineTimeText = machineTimeText + machineTimeSeconds + " sec";
        writeComment(machineTimeText);
        
		if (properties.generateMultiple && (i+1 < numberOfSections)) {
			if (tool.number != getSection(i+1).getTool().number) {
				writeln("");
				writeComment("Remaining operations located in additional files.");
				break;
			}
		}
	}

	writeln("");
	
	
	if (isFirstSection()) {
		writeBlock(gAbsIncModal.format(90), gFeedModeModal.format(94));
		writeBlock(gPlaneModal.format(17));
		switch (unit) {
			case IN:
				writeBlock(gUnitModal.format(20));
				break;
			case MM:
				writeBlock(gUnitModal.format(21));
				break;
		}
	} else {
		// Need to change from modal or the codes wont output in new
		writeBlock(gFormat.format(90), gFormat.format(94));
		writeBlock(gFormat.format(17));
		switch (unit) {
			case IN:
				writeBlock(gFormat.format(20));
				break;
			case MM:
				writeBlock(gFormat.format(21));
				break;
		}
	}
	writeln("");
}

function onOpen()
	{
	// Number of checks capturing fatal errors
	// 1. is CAD file in same units as our GRBL configuration ?
   // swarfer : GRBL obeys G20/21 so we should only need to output the correct code for the numbers we are outputting, I will look at this later
	if (unit != GRBLunits)
		{
		if (GRBLunits == MM)
			{
			alert("Error", "GRBL configured to mm - CAD file sends Inches! - Change units in CAD/CAM software to mm");
			error("Fatal Error : units mismatch between CADfile and GRBL setting");
			}
		else
			{
			alert("Error", "GRBL configured to inches - CAD file sends mm! - Change units in CAD/CAM software to inches");
			error("Fatal Error : units mismatch between CADfile and GRBL setting");
			}
		}

	// 2. is RadiusCompensation not set incorrectly ?
	onRadiusCompensation();

	// 3. moved to top of file
    myMachineConfig();

	// 4.  checking for duplicate tool numbers with the different geometry.
	if (true) {
		// check for duplicate tool number
		for (var i = 0; i < getNumberOfSections(); ++i) {
			var sectioni = getSection(i);
			var tooli = sectioni.getTool();
			if (i < (getNumberOfSections() - 1) && (tooli.number != getSection(i + 1).getTool().number)) {
				filesToGenerate++;
			}
			for (var j = i + 1; j < getNumberOfSections(); ++j) {
				var sectionj = getSection(j);
				var toolj = sectionj.getTool();
				if (tooli.number == toolj.number) {
					if (xyzFormat.areDifferent(tooli.diameter, toolj.diameter) ||
						xyzFormat.areDifferent(tooli.cornerRadius, toolj.cornerRadius) ||
						abcFormat.areDifferent(tooli.taperAngle, toolj.taperAngle) ||
						(tooli.numberOfFlutes != toolj.numberOfFlutes)) {
						error(
							subst(
								localize("Using the same tool number for different cutter geometry for operation '%1' and '%2'."),
								sectioni.hasParameter("operation-comment") ? sectioni.getParameter("operation-comment") : ("#" + (i + 1)),
								sectionj.hasParameter("operation-comment") ? sectionj.getParameter("operation-comment") : ("#" + (j + 1))
							)
						);
						return;
					}
				} else {
					if (properties.generateMultiple == false) {
						multipleToolError = true;
					}
				}
			}
		}
		if (multipleToolError) {
			alert("Warning", "Multiple tools found.  This post does not support tool changes.  You should repost and select True for Multiple Files in the post properties.");
		}
	}
	
	numberOfSections = getNumberOfSections();
	writeHeader(0);
   
}

function onComment(message)
	{
	writeComment(message);
	}

function forceXYZ()
	{
	xOutput.reset();
	yOutput.reset();
	zOutput.reset();
	xaOutput.reset();
	yaOutput.reset();
	zaOutput.reset();
	}

function forceAny()
	{
	forceXYZ();
	feedOutput.reset();
	}

function onSection()
	{
	var nmbrOfSections = getNumberOfSections();		// how many operations are there in total
	var sectionId = getCurrentSectionId();			// what is the number of this operation (starts from 0)
	var section = getSection(sectionId);			// what is the section-object for this operation
	var tool = section.getTool();

   if (!isFirstSection() && properties.generateMultiple && (tool.number != getPreviousSection().getTool().number))
      {		
		sequenceNumber ++;		
		//var fileIndexFormat = createFormat({width:3, zeropad: true, decimals:0});
  	   var path = FileSystem.replaceExtension(getOutputPath(), fileIndexFormat.format(sequenceNumber) + "of" + filesToGenerate + ".nc");
		redirectToFile(path);
		writeHeader(getCurrentSectionId());		
      } 	
   
	// Insert a small comment section to identify the related G-Code in a large multi-operations file
	var comment = "Operation " + (sectionId + 1) + " of " + nmbrOfSections;
	if (hasParameter("operation-comment"))
		{
		comment = comment + " : " + getParameter("operation-comment");
		}
	writeComment(comment);
	writeln("");

	// To be safe (after jogging to whatever position), move the spindle up to a safe home position before going to the initial position
	// At end of a section, spindle is retracted to clearance height, so it is only needed on the first section
	// it is done with G53 - machine coordinates, so I put it in front of anything else
	if (isFirstSection())
		{
		writeBlock(gAbsIncModal.format(90));	// Set to absolute coordinates
		if (isMilling())
			{
			writeBlock(gFormat.format(53), gMotionModal.format(0), "Z" + xyzFormat.format(properties.machineHomeZ));	// Retract spindle to Machine Z Home
			}
		}
   else 
      if (properties.generateMultiple && (tool.number != getPreviousSection().getTool().number))
         {
		   writeBlock(gFormat.format(90));	// Set to absolute coordinates
         if (isMilling()) 
            {
			   writeBlock(gFormat.format(53), gFormat.format(0), "Z" + xyzFormat.format(properties.machineHomeZ));	// Retract spindle to Machine Z Home
		      }
	      }

	// Write the WCS, ie. G54 or higher.. default to WCS1 / G54 if no or invalid WCS in order to prevent using Machine Coordinates G53
	if ((section.workOffset < 1) || (section.workOffset > 6))
		{
		alert("Warning", "Invalid Work Coordinate System. Select WCS 1..6 in CAM software. Selecting default WCS1/G54");
		//section.workOffset = 1;	// If no WCS is set (or out of range), then default to WCS1 / G54 : swarfer: this appears to be readonly
      writeBlock(gFormat.format(54));  // output what we want, G54
		}
   else
      {
	   writeBlock(gFormat.format(53 + section.workOffset));  // use the selected WCS
      }

	//var tool = section.getTool();

	// Insert the Spindle start command
	if (tool.clockwise)
		{
		writeBlock(sOutput.format(tool.spindleRPM), mFormat.format(3));
		}
	else if (properties.spindleTwoDirections)
		{
		writeBlock(sOutput.format(tool.spindleRPM), mFormat.format(4));
		}
	else
		{
		alert("Error", "Counter-clockwise Spindle Operation found, but your spindle does not support this");
		error("Fatal Error in Operation " + (sectionId + 1) + ": Counter-clockwise Spindle Operation found, but your spindle does not support this");
		return;
		}

	// Wait some time for spindle to speed up - only on first section, as spindle is not powered down in-between sections
	if (isFirstSection())
		{
		onDwell(properties.spindleOnOffDelay);
		}

	// If the machine has coolant, write M8 or M9
	if (properties.hasCoolant)
		{
		if (tool.coolant)
			{
			writeBlock(mFormat.format(8));
			}
		else
			{
			writeBlock(mFormat.format(9));
			}
		}

	forceXYZ();

	var remaining = currentSection.workPlane;
	if (!isSameDirection(remaining.forward, new Vector(0, 0, 1)))
		{
		alert("Error", "Tool-Rotation detected - GRBL only supports 3 Axis");
		error("Fatal Error in Operation " + (sectionId + 1) + ": Tool-Rotation detected but GRBL only supports 3 Axis");
		}
	setRotation(remaining);

	forceAny();

	// Rapid move to initial position, first XY, then Z
	var initialPosition = getFramePosition(currentSection.getInitialPosition());
	writeBlock(gAbsIncModal.format(90), gMotionModal.format(0), xOutput.format(initialPosition.x), yOutput.format(initialPosition.y));
	writeBlock(gMotionModal.format(0), zOutput.format(initialPosition.z));
	}

function onDwell(seconds)
	{
	writeBlock(gFormat.format(4), "P" + secFormat.format(seconds));
	}

function onSpindleSpeed(spindleSpeed)
	{
	writeBlock(sOutput.format(spindleSpeed));
	}

function onRadiusCompensation()
	{
	var radComp = getRadiusCompensation();
	var sectionId = getCurrentSectionId();
	if (radComp != RADIUS_COMPENSATION_OFF)
		{
		alert("Error", "RadiusCompensation is not supported in GRBL - Change RadiusCompensation in CAD/CAM software to Off/Center/Computer");
		error("Fatal Error in Operation " + (sectionId + 1) + ": RadiusCompensation is found in CAD file but is not supported in GRBL");
		return;
		}
	}

function onRapid(_x, _y, _z)
	{
	var x = xOutput.format(_x);
	var y = yOutput.format(_y);
	var z = zOutput.format(_z);
	if (x || y || z)
		{
		writeBlock(gMotionModal.format(0), x, y, z);
		feedOutput.reset();
		}
	}

function onLinear(_x, _y, _z, feed)
	{
	var x = xOutput.format(_x);
	var y = yOutput.format(_y);
	var z = zOutput.format(_z);
	var f = feedOutput.format(feed);

	if (x || y || z)
		{
		writeBlock(gMotionModal.format(1), x, y, z, f);
		}
	else if (f)
		{
		if (getNextRecord().isMotion())
			{
			feedOutput.reset(); // force feed on next line
			}
		else
			{
			writeBlock(gMotionModal.format(1), f);
			}
		}
	}

function onRapid5D(_x, _y, _z, _a, _b, _c)
	{
	alert("Error", "Tool-Rotation detected - GRBL only supports 3 Axis");
	error("Tool-Rotation detected but GRBL only supports 3 Axis");
	}

function onLinear5D(_x, _y, _z, _a, _b, _c, feed)
	{
	alert("Error", "Tool-Rotation detected - GRBL only supports 3 Axis");
	error("Tool-Rotation detected but GRBL only supports 3 Axis");
	}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed)
	{
	var start = getCurrentPosition();

	if (isFullCircle())
		{
		if (isHelical())
			{
			linearize(tolerance);
			return;
			}
		switch (getCircularPlane())
			{
			case PLANE_XY:
				writeBlock(gPlaneModal.format(17), gMotionModal.format(clockwise ? 2 : 3), xaOutput.format(x), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), feedOutput.format(feed));
				break;
			case PLANE_ZX:
				writeBlock(gPlaneModal.format(18), gMotionModal.format(clockwise ? 2 : 3), zaOutput.format(z), iOutput.format(cx - start.x, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
				break;
			case PLANE_YZ:
				writeBlock(gPlaneModal.format(19), gMotionModal.format(clockwise ? 2 : 3), yaOutput.format(y), jOutput.format(cy - start.y, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
				break;
			default:
				linearize(tolerance);
			}
		}
	else
		{
      switch (getCircularPlane())
			{
			case PLANE_XY:
				writeBlock(gPlaneModal.format(17), gMotionModal.format(clockwise ? 2 : 3), xaOutput.format(x), yaOutput.format(y), zaOutput.format(z), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), feedOutput.format(feed));
				break;
			case PLANE_ZX:
				writeBlock(gPlaneModal.format(18), gMotionModal.format(clockwise ? 2 : 3), xaOutput.format(x), yaOutput.format(y), zaOutput.format(z), iOutput.format(cx - start.x, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
				break;
			case PLANE_YZ:
				writeBlock(gPlaneModal.format(19), gMotionModal.format(clockwise ? 2 : 3), xaOutput.format(x), yaOutput.format(y), zaOutput.format(z), jOutput.format(cy - start.y, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
				break;
			default:
				linearize(tolerance);
			}
		}
	}

function onSectionEnd()
	{
	writeln("");
	// writeBlock(gPlaneModal.format(17));
	if (isRedirecting())	
	{
		if (!isLastSection() && properties.generateMultiple && (tool.number != getNextSection().getTool().number) || (isLastSection() && !isFirstSection()))
		{
			writeln("");
			onClose();
			closeRedirection();			
		}
	} 

	forceAny();
		
	}

function onClose()
	{
	writeBlock(gAbsIncModal.format(90));	// Set to absolute coordinates for the following moves
	if (isMilling())
		{
      gMotionModal.reset();  // for ease of reading the code always output the G0 words
		writeBlock(gAbsIncModal.format(90), gFormat.format(53), gMotionModal.format(0), "Z" + xyzFormat.format(properties.machineHomeZ));	// Retract spindle to Machine Z Home
		}
	writeBlock(mFormat.format(5));																					// Stop Spindle
	if (properties.hasCoolant)
		{
		writeBlock(mFormat.format(9));																				// Stop Coolant
		}
	//onDwell(properties.spindleOnOffDelay);																			// Wait for spindle to stop
   gMotionModal.reset();
	if (properties.gotoMCSatend)
      {  // go to MCS home
      writeBlock(gAbsIncModal.format(90), gFormat.format(53), gMotionModal.format(0), "X" + xyzFormat.format(properties.machineHomeX), "Y" + xyzFormat.format(properties.machineHomeY));	// Return to home position
      }
   else
      {  // go to WCS home
      writeBlock(gAbsIncModal.format(90), gMotionModal.format(0), "X" + xyzFormat.format(properties.machineHomeX), "Y" + xyzFormat.format(properties.machineHomeY));	
      }
	writeBlock(mFormat.format(30));  // Program End
	writeln("%");							// EndOfFile marker
	}

function onTerminate()
{
	//The idea here was to rename the first file to <filename>.001ofX.nc so that when multiple files were generated, they all had the same naming conventionl
	//While this does work, the auto load into Brackets loads a log file instead of the gcode file.

	//var fileIndexFormat = createFormat({width:3, zeropad: true, decimals:0});
	//FileSystem.moveFile(getOutputPath(), FileSystem.replaceExtension(getOutputPath(), fileIndexFormat.format(1) + "of" + filesToGenerate + ".nc"));
}


