var mysql = require('mysql');
var Address = require('./address').Address;

exports.register = function () {
    this.inherits("queue/discard");
    this.register_hook("rcpt", "aliases_mysql");
};

exports.aliases_mysql = function (next, connection, params) {
    var rcpt = params && params[0].address();
    if(!connection.transaction.notes.local_sender){
        return next()
    }

    this.init_mysql(connection);
    this.get_forwarder_by_email(connection, rcpt, function(error, forwarder){
        if (error){
            connection.logdebug(exports, "Error: " + error.message);
            return next();
        }

        switch (forwarder.action.toLowerCase()) {
            case "drop":
                exports.drop(connection, rcpt);
                next(DENY);
                break;
            case "alias":
                exports.alias(connection, rcpt, forwarder);
                next(OK);
                break;
            default:
                connection.loginfo(exports, "unknown action: " + forwarder.action);
                next()
        }
    });
};

exports.get_forwarder_by_email = function(connection, email, cb){
    var notes = server.notes.aliases_mysql;
    var query = notes.config.main.alias_query.replace(/%u/g, email);

    notes.pool.connect(function(error, conn) {
        if (error) return cb(error);

        connection.logdebug(exports, 'exec query: ' + query);
        conn.query(query, [], function(error, results) {
            if (error) return cb(error);
            if (results[0] && results[0].address === email) {
                return cb(null, results[0]);
            }

            cb(new Error("No forwarder entry for "+ email));
        });
    });
};

exports.drop = function(connection, rcpt) {
    connection.logdebug(exports, "marking " + rcpt + " for drop");
    connection.transaction.notes.discard = true;
};

exports.alias = function(connection, rcpt, forwarder) {
    if (forwarder === null || !forwarder.aliases || forwarder.aliases.length === 0) {
        connection.loginfo(exports, 'alias failed for ' + rcpt + ', no "to" field in alias config');
        return false;
    }

    connection.transaction.rcpt_to.pop();
    connection.relaying = true;

    var aliases = forwarder.aliases.split("|");
    for(var index=0; index < aliases.length; index++){
        connection.logdebug(exports, "aliasing " + rcpt + " to " + aliases[index]);
        connection.transaction.rcpt_to.push(new Address('<' + aliases[index] + '>'));
    }
};

exports.init_mysql = function(connection){
    if (!server.notes.aliases_mysql || !server.notes.aliases_mysql.pool) {
        var config = exports.config.get('aliases_mysql.ini', {
            host: 'localhost',
            port: 3306,
            char_set: 'UTF8_GENERAL_CI',
            ssl: false,
            alias_query: "SELECT * FROM aliases WHERE email = '%u'"
        });

        var connect = function(callback) {
            var self = this;
            if (self.connection === undefined){
                self.pool = mysql.createPool({
                    host : config.main.host,
                    port : config.main.port,
                    charset: config.main.charset,
                    user : config.main.user,
                    password: config.main.password,
                    database: config.main.database
                }).getConnection(function(error, conn){
                    self.connection = conn;
                    callback(error, self.connection);
                });

                return;
            }


            return callback(null, self.connection);
        };

        server.notes.aliases_mysql = {
            config: config,
            pool  : {connect: connect}
        };
    }

    connection.logdebug(exports,
            'MySQL host="' + server.notes.aliases_mysql.config.main.host + '"' +
            ' port="' + server.notes.aliases_mysql.config.main.port + '"' +
            ' user="' + server.notes.aliases_mysql.config.main.user + '"' +
            ' database="' + server.notes.aliases_mysql.config.main.database+ '"');
};