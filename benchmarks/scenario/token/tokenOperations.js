/*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

'use strict';

module.exports.info  = 'token_operations';

let bc, contx;
let domains, users;
let current_users = 0;
let user_arrays;
const initial_balance = 1000000;
const exchange_rate = 1.0;
const operation_type = ['issue_token','send_token','exchange_token'];
let prefix;

/**
 * Get user index in specified domain
 * @param {Number} domain Domain index.
 * @return {Number} User index.
 */
function getUser(domain) {
    return Math.floor(Math.random()*Math.floor(user_arrays[domain].length));
}

/**
 * Get two users in specified domains
 * @param {Number} domain1 Domain index.
 * @param {Number} domain2 Domain index.
 * @return {Array} Index of two users.
 */
function get2Users(domain1, domain2) {
    let idx1 = getUser(domain1);
    let idx2;
    do {
        idx2 = getUser(domain2);
    } while (domain1 === domain2 && idx1 === idx2);
    return [idx1, idx2];
}

/**
 * Get domain index
 * @return {Number} Domain index.
 */
function getDomain() {
    return Math.floor(Math.random() * Math.floor(domains));
}

/**
 * Get two domains
 * @return {Array} Index of two domains.
 */
function get2Domains() {
    let idx1 = getDomain();
    let idx2;
    do {
        idx2 = getDomain();
    } while (idx1 === idx2);
    return [idx1, idx2];
}

/**
 * Generate unique user key for the transaction.
 * @returns {Number} User key.
 **/
function generateUser() {
    // should be [a-z]{1,9}
    if (typeof prefix === 'undefined') {
        prefix = process.pid;
    }
    let num = prefix.toString() + current_users.toString();
    return parseInt(num);
}

/**
 * Generates random string.
 * @returns {string} random string from possible characters
 **/
function random_string() {
    let text = '';
    const possible = 'ABCDEFGHIJKL MNOPQRSTUVWXYZ abcdefghij klmnopqrstuvwxyz';

    for (let i = 0; i < 12; i++) {
        text += possible.charAt(Math.floor(Math.random() * possible.length));
    }
    return text;
}

/**
 * Generates small bank workload with specified number of users
 * and operations.
 * @returns {Object} array of json objects and each denotes
 * one operations
 **/
function generateWorkload() {
    let workload = [];
    if (current_users < users*domains) {
        let user_id = generateUser();
        let domain_id = current_users % domains;
        user_arrays[domain_id].push(user_id);
        let acc = {
            'user_id': user_id,
            'user_name': random_string(),
            'domain_id': domain_id,
            'initial_balance': initial_balance,
            'transaction_type': 'create_user'
        };
        current_users++;
        workload.push(acc);
    } else {
        let op_index =
            Math.floor(Math.random() * Math.floor(operation_type.length));
        let random_op = operation_type[op_index];
        let amount = Math.floor(Math.random() * 200);
        let op_payload;
        switch (random_op) {
            case 'issue_token': {
                let domain_index = getDomain();
                let user_index = getUser(domain_index);
                let user_id = user_arrays[domain_index][user_index];
                op_payload = {
                    'amount': amount,
                    'user_id': user_id,
                    'transaction_type': random_op
                };
                break;
            }
            case 'send_token': {
                let domain_index = getDomain();
                let users = get2Users(domain_index, domain_index);
                let dest_id = user_arrays[domain_index][users[0]];
                let source_id = user_arrays[domain_index][users[1]];
                op_payload = {
                    'amount': amount,
                    'dest_user_id': dest_id,
                    'source_user_id': source_id,
                    'transaction_type': random_op
                };
                break;
            }
            case 'exchange_token': {
                let domains = get2Domains();
                let users = get2Users(domains[0], domains[1]);
                let dest_id = user_arrays[domains[0]][users[0]];
                let source_id = user_arrays[domains[1]][users[1]];
                op_payload = {
                    'amount': amount,
                    'exchange_rate': exchange_rate,
                    'dest_user_id': dest_id,
                    'source_user_id': source_id,
                    'transaction_type': random_op
                };
                break;
            }
            default: {
                throw new Error('Invalid operation!!!');
            }
        }
        workload.push(op_payload);
    }

    return workload;
}

module.exports.init = function(blockchain, context, args) {
    if(!args.hasOwnProperty('domains')) {
        return Promise.reject(new Error('token.operations - \'domains\' is missed in the arguments'));
    }
    if(!args.hasOwnProperty('users')) {
        return Promise.reject(new Error('token.operations - \'users\' is missed in the arguments'));
    }
    domains = args.domains;
    if(domains <= 1) {
        return Promise.reject(new Error('token.operations - number domains should be more than 1'));
    }
    users = args.users;
    if(users <= 3) {
        return Promise.reject(new Error('token.operations - number users should be more than 3'));
    }

    // User array for each domain
    if (typeof user_arrays === 'undefined') {
        user_arrays = Array.from(new Array(domains), () => new Array());
    }

    bc = blockchain;
    contx = context;

    return Promise.resolve();
};

module.exports.run = function() {
    let args = generateWorkload();

    // rearrange arguments for the Fabric adapter
    if (bc.bcType === 'fabric') {
        let ccpArgs = [];
        for (let arg of args) {
            let tempArgs = Object.values(arg);
            let functionArgs = [tempArgs[0].toString(), tempArgs[1].toString(), tempArgs[2].toString(), tempArgs[3].toString()];
            ccpArgs.push({
                chaincodeFunction: arg.transaction_type,
                chaincodeArguments: functionArgs,
            });
        }

        args = ccpArgs;
    }

    return bc.invokeSmartContract(contx, 'token', '1.0', args, 30);
};

module.exports.end = function() {
    return Promise.resolve();
};

module.exports.user_arrays = user_arrays;
