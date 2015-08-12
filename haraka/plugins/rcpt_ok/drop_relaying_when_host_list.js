//rcpt_ok/drop_relaying_when_host_list

"use strict";

exports.hook_rcpt_ok = function(next, connection, params) {
  var txn = connection.transaction;
    if (!txn) { return; }

  var results = txn.results.get('rcpt_to.in_host_list');
  if(results && connection.relaying && results.pass.indexOf('rcpt_to') != -1) {
    this.logdebug('rcpt_ok.drop_relaying_when_host_list', "dropped connection relaying because of passed rcpt_to.in_host_list");
    delete connection.relaying;
  }

  return next();
}
