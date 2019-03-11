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
 reads workflow.json to get approver id, approver name and approval flow flag

COMMANDS:
 None

Dependencies:
 "fs"
*/

var fs = require('fs')
var obj = '';
function readworkflow(callback) {

 if(!obj){
 obj = JSON.parse(fs.readFileSync('./workflow.json', 'utf8'));}

callback(null, obj,null);
}
module.exports = {
  readworkflow_coffee: readworkflow	// MAIN FUNCTION
  
}