#-------------------------------------------------------------------------------
# Copyright 2018 Cognizant Technology Solutions
#   
#   Licensed under the Apache License, Version 2.0 (the "License"); you may not
#   use this file except in compliance with the License.  You may obtain a copy
#   of the License at
#   
#     http://www.apache.org/licenses/LICENSE-2.0
#   
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#   WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
#   License for the specific language governing permissions and limitations under
#   the License.
#-------------------------------------------------------------------------------

#Description:
# This script listens to commands handled by Teamcity bot,
# passes them to the appropriate js files for execution,
# Returns the result of execution back to user
#
#Configuration:
# HUBOT_NAME
# HUBOT_TEAMCITY_URL
# HUBOT_TEAMCITY_USERNAME
# HUBOT_TEAMCITY_PWD
#
#Dependencies:
# "request": "2.81.0"
index = require('./index')
# Required for project functionality
listprojects = require("./listprojects.js")
createproject = require("./createproject.js")
deleteproject = require("./deleteproject.js")
listusers     = require("./listusers.js")
createuser    = require("./createuser.js")
listbuildqueue    = require("./listbuildqueue.js")
listbuildtypes    = require("./listbuildtypes.js")
showbuild    = require("./showbuild.js")
createbuildconfig  = require("./createbuildconfig.js")
startbuildq    = require("./startbuildq.js")
cancelbuildq    = require("./cancelbuildq.js")

# Required for approval flow creation(inserting data into mongodb)
readjson	 = require ('./readjson.js');
generate_id = require('./mongoConnt');

#Environment Variables required
url      = process.env.HUBOT_TEAMCITY_URL
username = process.env.HUBOT_TEAMCITY_USERNAME
pwd      = process.env.HUBOT_TEAMCITY_PWD

#Help content
helpcontents =""
helpcontents+="\nlist project --> to view the list of projects"
helpcontents+="\ncreate project {projectid} {buildtypeid} --> to create a new project"
helpcontents+="\ndelete project {projectname} --> to delete a project"
helpcontents+="\nlist user --> to view the list of users"
helpcontents+="\ncreate user {name} {username} {password} --> to create a new user"
helpcontents+="\nlist buildtypes --> to view the list of buildtypes(buildconfiguration)"
helpcontents+="\nstart build {buildtypeid} --> to start build using buildtypeid(buildconfiguration)"
helpcontents+="\nlist buildqueue --> to view the list of builds buildQueue"
helpcontents+="\nshow buildid {buildid} --> to view the status of completed build using buildid"
helpcontents+="\nshow build {buildtypeid} --> to view the status of latest completed build using buildtypeid(buildconfiguration)"
helpcontents+="\ncancel buildqueue {buildid} --> to cancel a build in build queue"

module.exports = (robot) ->
# HELP
	robot.respond /help/i, (res) ->
		res.send helpcontents
		setTimeout (->index.passData helpcontents),1000

# To list all the project of a Teamcity
	robot.respond /list project/i, (res) ->
		listprojects.prj_lst url,username,pwd,(listProject) ->
			res.send listProject
			setTimeout (->index.passData listProject),1000

# To list all users of a Teamcity
	robot.respond /list user/i, (res) ->
		listusers.usr_lst url,username,pwd,(listUser) ->
			res.send listUser
			setTimeout (->index.passData listUser),1000

# To create new user in Teamcity
	robot.respond /create user (.+)/i, (res) ->
		name = res.match[1].split(' ')[0]
		usrname = res.match[1].split(' ')[1]
		passwd = res.match[1].split(' ')[2]
		readjson.readworkflow_coffee (error,stdout,stderr) ->
			#Checks for approval flow in the workflow.json file
			if stdout.createuser.workflowflag == true
				#Generate Random Ticket Number
				generate_id.getNextSequence (err,id) ->
					tckid=id
					payload={botname:process.env.HUBOT_NAME,username:res.message.user.name,userid:res.message.user.reply_to,podIp:process.env.MY_POD_IP,"callback_id":"createuser",name:name,usrname:usrname,passwd:passwd}
					#To send Accept/Reject request to the chat room#
					message='Ticket Id : '+tckid+'\n Raised By: '+res.message.user.name+'\n Command: '+res.match[0];
					robot.messageRoom(stdout.createuser.adminid, message);
					res.send 'Your request is waiting for approval by '+stdout.createuser.admin
					#To Insert the payload including ticket number into mongodb#
					dataToInsert = {ticketid: tckid, payload: payload, "status":"","approvedby":""}
					#Insert into Mongo with Payload
					generate_id.add_in_mongo dataToInsert
			#Casual workflow
			else
				createuser.usr_crte url,username,pwd,name,usrname,passwd,(createUser) ->
					res.send createUser
					setTimeout (->index.passData createUser),1000
	
	robot.router.post '/createuser', (request, response) ->
		data_http = if request.body.payload? then JSON.parse request.body.payload else request.body
		console.log("inside createuser");
		if data_http.action == "Approved"
			dt='Your request is approved by '+data_http.approver+' for create user';
			# Approved Message send to the user chat room
			robot.messageRoom data_http.userid, dt;
			name = request.body.name;
			usrname = request.body.usrname;
			passwd = request.body.passwd;
			# Call from create_project file for project creation
			createuser.usr_crte url,username,pwd,name,usrname,passwd,(createUser) ->
				robot.messageRoom(data_http.userid,createUser)
				setTimeout (->index.passData createUser),1000
		else
			dt="create user request was rejected by "+data_http.approver
			# Rejected Message send to the user chat room
			robot.messageRoom data_http.userid, dt;
			setTimeout (->index.passData dt),1000

# To list the buildQueue in Teamcity
	robot.respond /list buildqueue/i, (res) ->
		listbuildqueue.buildqueue_lst url,username,pwd,(listBuildQueue) ->
			res.send listBuildQueue
			setTimeout (->index.passData listBuildQueue),1000

# To list the buildTypes in Teamcity
	robot.respond /list buildtypes/i, (res) ->
		listbuildtypes.bld_typ_lst url,username,pwd,(listBuildType) ->
			res.send listBuildType
			setTimeout (->index.passData listBuildType),1000

# To view particular buildid in Teamcity
	robot.respond /show build (.*)/i, (res) ->
		bldtyp =res.match[1]
		showbuild.bld_shw url,username,pwd,"",bldtyp,(showBuild,bldid) ->
			res.send showBuild
			setTimeout (->index.passData showBuild),1000

	robot.respond /show buildid (.*)/i, (res) ->
		bldid =res.match[1]
		showbuild.bld_shw url,username,pwd,bldid,"",(showBuild,bldid) ->
			res.send showBuild
			setTimeout (->index.passData showBuild),1000

# To start build using 'buildType id' of a Teamcity project
	robot.respond /start build (.*)/i, (res) ->
		bldtyp =res.match[1]
		readjson.readworkflow_coffee (error,stdout,stderr) ->
			#Checks for approval flow in the workflow.json file
			if stdout.startbuild.workflowflag == true
				#Generate Random Ticket Number
				generate_id.getNextSequence (err,id) ->
					tckid=id
					payload={botname:process.env.HUBOT_NAME,username:res.message.user.name,userid:res.message.user.reply_to,podIp:process.env.MY_POD_IP,"callback_id":"startbuild",bldtyp:bldtyp}
					#To send Accept/Reject request to the chat room#
					message='Ticket Id : '+tckid+'\n Raised By: '+res.message.user.name+'\n Command: '+res.match[0];
					robot.messageRoom(stdout.startbuild.adminid, message);
					res.send 'Your request is waiting for approval by '+stdout.startbuild.admin
					#To Insert the payload including ticket number into mongodb#
					dataToInsert = {ticketid: tckid, payload: payload, "status":"","approvedby":""}
					#Insert into Mongo with Payload
					generate_id.add_in_mongo dataToInsert
			#Casual workflow
			else
				startbuildq.bld_start url,username,pwd,bldtyp,(startBuild,bldid) ->
					res.send startBuild
					if(bldid!="")
						run=() ->
								showbuild.bld_shw url,username,pwd,bldid,"",(showBuild,res_buildid) ->
									if(res_buildid==bldid)								
										robot.messageRoom(res.message.user.reply_to,showBuild )
										setTimeout (->index.passData showBuild),1000
										clearInterval runInterval
						runInterval=setInterval(run, 15000)
	robot.router.post '/startbuild', (request, response) ->
		data_http = if request.body.payload? then JSON.parse request.body.payload else request.body
		if data_http.action == "Approved"
			dt='Your request is approved by '+data_http.approver+' for start a build using buildType id';
			# Approved Message send to the user chat room
			robot.messageRoom data_http.userid, dt;
			bldtyp = request.body.bldtyp;
			# Call for trigger build using payload already provided when requesting
			startbuildq.bld_start url,username,pwd,bldtyp,(startBuild,bldid) ->
				robot.messageRoom(data_http.userid,startBuild )
				if(bldid!="")
					run=() ->
							showbuild.bld_shw url,username,pwd,bldid,"",(showBuild,res_buildid) ->
								if(res_buildid==bldid)								
									robot.messageRoom(data_http.userid,showBuild )
									setTimeout (->index.passData showBuild),1000
									clearInterval runInterval
					runInterval=setInterval(run, 15000)
		else
			dt="start build request was rejected by "+data_http.approver
			# Rejected Message send to the user chat room
			robot.messageRoom data_http.userid, dt;
			setTimeout (->index.passData dt),1000

# To cancel build in Queue 'build id' of a Teamcity project
	robot.respond /cancel buildqueue (.*)/i, (res) ->
		bqid =res.match[1]
		readjson.readworkflow_coffee (error,stdout,stderr) ->
			#Checks for approval flow in the workflow.json file
			if stdout.cancelbuildq.workflowflag == true
				#Generate Random Ticket Number
				generate_id.getNextSequence (err,id) ->
					tckid=id
					payload={botname:process.env.HUBOT_NAME,username:res.message.user.name,userid:res.message.user.reply_to,podIp:process.env.MY_POD_IP,"callback_id":"cancelbuildq",bqid:bqid}
					#To send Accept/Reject request to the chat room#
					message='Ticket Id : '+tckid+'\n Raised By: '+res.message.user.name+'\n Command: '+res.match[0];
					robot.messageRoom(stdout.cancelbuildq.adminid, message);
					res.send 'Your request is waiting for approval by '+stdout.cancelbuildq.admin
					#To Insert the payload including ticket number into mongodb#
					dataToInsert = {ticketid: tckid, payload: payload, "status":"","approvedby":""}
					#Insert into Mongo with Payload
					generate_id.add_in_mongo dataToInsert
			#Casual workflow
			else
				cancelbuildq.bld_cancel url,username,pwd,bqid,(cancelBuildq) ->
					res.send cancelBuildq
					setTimeout (->index.passData cancelBuildq),1000
	
	robot.router.post '/cancelbuildq', (request, response) ->
		data_http = if request.body.payload? then JSON.parse request.body.payload else request.body
		if data_http.action == "Approved"
			dt='Your request is approved by '+data_http.approver+' for cancel buildq';
			# Approved Message send to the user chat room
			robot.messageRoom data_http.userid, dt;
			bqid = request.body.bqid;
			# Call from create_project file for project creation
			cancelbuildq.bld_cancel url,username,pwd,bqid,(cancelBuildq) ->
				robot.messageRoom(data_http.userid,cancelBuildq )
				setTimeout (->index.passData cancelBuildq),1000
		else
			dt="cancle buildq request was rejected by "+data_http.approver
			# Rejected Message send to the user chat room
			robot.messageRoom data_http.userid, dt;
			setTimeout (->index.passData dt),1000
			

# To Create buildtype in buildconfig of a Teamcity project
	robot.respond /create buildconfig (.+)/i, (res) ->
		projectid = res.match[1].split(' ')[0]
		projectname = res.match[1].split(' ')[1]
		buildtypeid = res.match[1].split(' ')[2]
		buildtypename = res.match[1].split(' ')[3]
		readjson.readworkflow_coffee (error,stdout,stderr) ->
			#Checks for approval flow in the workflow.json file
			if stdout.createbuildconfig.workflowflag == true
				#Generate Random Ticket Number
				generate_id.getNextSequence (err,id) ->
					tckid=id
					payload={botname:process.env.HUBOT_NAME,username:res.message.user.name,userid:res.message.user.reply_to,podIp:process.env.MY_POD_IP,"callback_id":"createbuildconfig",projectid:projectid,projectname:projectname,buildtypeid:buildtypeid,buildtypename:buildtypename}
					#To send Accept/Reject request to the chat room#
					robot.messageRoom(stdout.createbuildconfig.adminid, message);
					res.send 'Your request is waiting for approval by '+stdout.createbuildconfig.admin
					#To Insert the payload including ticket number into mongodb#
					dataToInsert = {ticketid: tckid, payload: payload, "status":"","approvedby":""}
					#Insert into Mongo with Payload
					generate_id.add_in_mongo dataToInsert
			#Casual workflow
			else
				createbuildconfig.bldtyp_crte url,username,pwd,projectname,projectid,buildtypeid,buildtypename,(createBuildConf) ->
					res.send createBuildConf
					setTimeout (->index.passData createBuildConf),1000
	
	robot.router.post '/createbuildconfig', (request, response) ->
		data_http = if request.body.payload? then JSON.parse request.body.payload else request.body
		if data_http.action == "Approved"
			dt='Your request is approved by '+data_http.approver+' for create buildconfig';
			# Approved Message send to the user chat room
			robot.messageRoom data_http.userid, dt;
			projectid = request.body.projectid;
			projectname = request.body.projectname;
			buildtypeid = request.body.buildtypeid;
			buildtypename = request.body.buildtypename;
			# Call from create_project file for project creation
			createbuildconfig.bldtyp_crte url,username,pwd,projectid,projectname,buildtypeid,buildtypename,(createBuildConf) ->
				robot.messageRoom(data_http.userid,createBuildConf )
				setTimeout (->index.passData createBuildConf),1000
		else
			dt="create build configuration request was rejected by "+data_http.approver
			# Rejected Message send to the user chat room
			robot.messageRoom data_http.userid, dt;
			setTimeout (->index.passData dt),1000

# To Create a Teamcity project
	robot.respond /create project (.+)/i, (res) ->
		projectid = res.match[1].split(' ')[0]
		buildtypeid = res.match[1].split(' ')[1]
		readjson.readworkflow_coffee (error,stdout,stderr) ->
			#Checks for approval flow in the workflow.json file
			if stdout.createproject.workflowflag == true
				#Generate Random Ticket Number
				generate_id.getNextSequence (err,id) ->
					tckid=id
					payload={botname:process.env.HUBOT_NAME,username:res.message.user.name,userid:res.message.user.reply_to,podIp:process.env.MY_POD_IP,"callback_id":"createproject",projectid:projectid,buildtypeid:buildtypeid}
					#To send Accept/Reject request to the chat room#
					message='Ticket Id : '+tckid+'\n Raised By: '+res.message.user.name+'\n Command: '+res.match[0];
					robot.messageRoom(stdout.createproject.adminid, message);
					res.reply 'Your request is waiting for approval by '+stdout.createproject.admin
					#To Insert the payload including ticket number into mongodb#
					dataToInsert = {ticketid: tckid, payload: payload, "status":"","approvedby":""}
					#Insert into Mongo with Payload
					generate_id.add_in_mongo dataToInsert
			#Casual workflow
			else
				createproject.prj_crte url,username,pwd,projectid,buildtypeid,(createProject) ->
					res.send createProject
					setTimeout (->index.passData createProject),1000
	
	robot.router.post '/createproject', (request, response) ->
		data_http = if request.body.payload? then JSON.parse request.body.payload else request.body
		if data_http.action == "Approved"
			dt='Your request is approved by '+data_http.approver+' for create project';
			# Approved Message send to the user chat room
			robot.messageRoom data_http.userid, dt;
			projectid = request.body.projectid;
			buildtypeid = request.body.buildtypeid;
			# Call from create_project file for project creation
			createproject.prj_crte url,username,pwd,projectid,buildtypeid,(createProject) ->
				robot.messageRoom(data_http.userid,createProject )
				setTimeout (->index.passData createProject),1000
		else
			dt="create project request was rejected by "+data_http.approver
			# Rejected Message send to the user chat room
			robot.messageRoom data_http.userid, dt;
			setTimeout (->index.passData dt),1000

# To delete a Teamcity project
	robot.respond /delete project (.*)/i, (res) ->
		projectid = res.match[1]
		readjson.readworkflow_coffee (error,stdout,stderr) ->
			#Checks for approval flow in the workflow.json file
			if stdout.deleteproject.workflowflag == true
				#Generate Random Ticket Number
				generate_id.getNextSequence (err,id) ->
					tckid=id
					payload={botname:process.env.HUBOT_NAME,username:res.message.user.name,userid:res.message.user.reply_to,podIp:process.env.MY_POD_IP,"callback_id":"deleteproject",projectid:projectid}
					message='Ticket Id : '+tckid+'\n Raised By: '+res.message.user.name+'\n Command: '+res.match[0];
					robot.messageRoom(stdout.deleteproject.adminid, message);
					res.send 'Your request is waiting for approval by '+stdout.deleteproject.admin
					dataToInsert = {ticketid: tckid, payload: payload, "status":"","approvedby":""}
					#Insert into Mongo with Payload
					generate_id.add_in_mongo dataToInsert
			#Casual workflow
			else
				deleteproject.prj_del url,username,pwd,projectid,(deleteProject) ->
					res.send deleteProject
					setTimeout (->index.passData deleteProject),1000
					
	robot.router.post '/deleteproject', (request, response) ->
		data_http = if request.body.payload? then JSON.parse request.body.payload else request.body
		if data_http.action == "Approved"
			dt='Your request is approved by '+data_http.approver+' for delete project';
			# Approved Message send to the user chat room
			robot.messageRoom data_http.userid, dt;
			projectid = request.body.projectid;
			# Call from create_project file for project creation 
			deleteproject.prj_del url,username,pwd,projectid,(deleteProject) ->
				robot.messageRoom(data_http.userid,deleteProject)
				setTimeout (->index.passData deleteProject),1000
		else
			dt="delete project request was rejected by "+data_http.approver
			# Rejected Message send to the user chat room
			robot.messageRoom data_http.userid, dt;
			setTimeout (->index.passData dt),1000
