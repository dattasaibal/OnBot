/*******************************************************************************
*Copyright 2018 Cognizant Technology Solutions
* 
* Licensed under the Apache License, Version 2.0 (the "License"); you may not
* use this file except in compliance with the License.  You may obtain a copy
* of the License at
* 
*   http://www.apache.org/licenses/LICENSE-2.0
* 
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
* WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
* License for the specific language governing permissions and limitations under
* the License.
 ******************************************************************************/

/*Description:
 Passes all hubot health related matrices to elasticsearch

Configuration:
 MONITOR_INTERVAL
 HUBOT_NAME
 MONITOR_RETENSION

COMMANDS:
 None

Dependencies:
 "elasticSearch": "^0.9.2"
 "monitor": "0.6.10"
*/

const healthlogger = require('./lib/healthlogger');
module.exports = (robot) => {
  var passHealthData = function () {
    require('monitor').start();

	function formatAMPM(date) {
  var hours = date.getHours();
  var minutes = date.getMinutes();
  var ampm = hours >= 12 ? 'pm' : 'am';
  hours = hours % 12;
  hours = hours ? hours : 12; // the hour '0' should be '12'
  minutes = minutes < 10 ? '0'+minutes : minutes;
  var strTime = hours + ':' + minutes + ' ' + ampm;
  return strTime;
}
    // Low memory warning monitor
	var Monitor = require('monitor');
	var LOW_MEMORY_THRESHOLD = 10000000000000000000000000000;

	//robot.messageRoom(room, '111');

	// Set the probe to push changes every 2 minutes
	var options = {
	  hostName: 'localhost',
	  probeClass: 'Process',
	  initParams: {
    	pollInterval: process.env.MONITOR_INTERVAL || 120000
  		}
	}
	var jsonout= "";
	var jsonobj={};
	jsonobj.Botname;
	jsonobj.timestamp=[];
	jsonobj.Total_memeory=[];
	jsonobj.used_memory=[];
	jsonobj.Free_memory=[];
	jsonobj.Total_heap=[];
	jsonobj.Used_heap=[];
	jsonobj.free_heap=[];
	jsonobj.rss=[];
	jsonobj.uptime;
	var processMonitor = new Monitor(options);
	// Attach the change listener
	processMonitor.on('change', function() {
	  var p = processMonitor.get('platform');
	  var ver = processMonitor.get('version');
	  var freemem = processMonitor.get('freemem');
	  var pid = processMonitor.get('pid');
	  var pm = processMonitor.get('heapUsed');
	  var cp = processMonitor.get('cpus');
	  var tm = processMonitor.get('totalmem');
	  var lavg = processMonitor.get('loadavg');
	  var otime = processMonitor.get('osUptime');
	  var hname = processMonitor.get('hostname');
	  var uid = processMonitor.get('uid');
	  var ht = processMonitor.get('heapTotal');
	  var cwd = processMonitor.get('cwd');
	  var uptime = processMonitor.get('uptime');
	  var arch = processMonitor.get('arch');
	  //high thread local storage rss, resident set size (RSS) is the portion of memory occupied by a process 
	  var rss = processMonitor.get('rss');
	  var vsize = processMonitor.get('vsize');
	  var title = processMonitor.get('title');
	  
	  var freeheap=ht-pm;
	  var usedmemory=tm-freemem;
					jsonobj.Botname=process.env.HUBOT_NAME;
					jsonobj.timestamp.push(Date.now());      //for ampm [formatAMPM(new Date())]
					jsonobj.Total_memeory.push(tm);
					jsonobj.used_memory.push(usedmemory);
					jsonobj.Free_memory.push(freemem);
					jsonobj.Total_heap.push(ht);
					jsonobj.Used_heap.push(pm);
					jsonobj.free_heap.push(freeheap);
					jsonobj.rss.push(rss);
					jsonobj.uptime=uptime;
					
					if((process.env.MONITOR_RETENSION || 60)<jsonobj.timestamp.length){
						
						jsonobj.timestamp.shift();
						jsonobj.Total_memeory.shift();
						jsonobj.used_memory.shift();
						jsonobj.Free_memory.shift();
						jsonobj.Total_heap.shift();
						jsonobj.Used_heap.shift();
						jsonobj.free_heap.shift();
						jsonobj.rss.shift();
					}
					healthlogger.healthData(jsonobj, (err) => {
						if (err) return robot.logger.error(err.message);
					});
	  
	});

	// Now connect the monitor
	processMonitor.connect(function(error) {
	  if (error) {
	    console.error('Error connecting with the process probe: ', error);
	    process.exit(1);
	  }
	});

	;
	
  };

  passHealthData();
};

// ---
// generated by coffee-script 1.9.2