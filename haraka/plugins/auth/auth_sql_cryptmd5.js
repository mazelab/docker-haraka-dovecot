var net_utils = require('./net_utils');
var mysql = require('mysql');
var cryptmd5 = require("./cryptmd5.js");

exports.register = function() {
    this.inherits('auth/auth_base');
};

exports.hook_capabilities = function(next, connection) {
    // Do not allow AUTH unless private IP or encrypted
    if (!net_utils.is_rfc1918(connection.remote_ip) && !connection.using_tls) {
        return next();
    }

    var methods = ["PLAIN", "LOGIN"];
    connection.capabilities.push('AUTH ' + methods.join(' '));
    connection.notes.allowed_auth_methods = methods;

    return next();
};

exports.init_mysql = function(connection) {
    if (!server.notes.auth_cryptmd5 || !server.notes.auth_cryptmd5.pool) {
        var config = this.config.get('auth_sql_cryptmd5.ini', {
            host: 'localhost',
            port: 3306,
            char_set: 'UTF8_GENERAL_CI',
            ssl: false,
            password_query: "SELECT pw_passwd AS password FROM `%d` WHERE pw_name = '%n'"
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

        server.notes.auth_cryptmd5 = {
            config: config,
            pool  : {connect: connect}
        };
    }
};

exports.get_plain_passwd = function(connection, user, cb) {

    var notes = server.notes.auth_cryptmd5;
    var query = null;

    connection.logdebug(exports, 'MySQL host="' + notes.config.main.host + '"' +
            ' port="' + notes.config.main.port + '"' +
            ' user="' + notes.config.main.user + '"' +
            ' database="' + notes.config.main.database+ '"');
    connection.logdebug(exports, "entire user: " + user);

    notes.pool.connect(function(err, conn) {
        if (err) return cb(err);

        var name   = user.split("@")[0];
        var domain = user.split("@")[1] || null;
        if (domain === null){
            return cb(new Error("wrong login format for user: "+ name));
        }

        query = notes.config.main.password_query;
        query = query.replace(/%d/g,domain).replace(/%n/g, name).replace(/%u/g, user);

        connection.logdebug(exports, 'exec query: ' + query);
        conn.query(query, [user], function(err, results) {
            if (err) return cb(err);

            if ((results[0] && results[0].user || null) === user) {
                return cb(null, results[0].password);
            }

            cb(new Error("No such user "+ user));
        });
    });
};

exports.check_plain_passwd = function (connection, user, passwd, cb) {
    this.init_mysql(connection);
    this.get_plain_passwd(connection, user, function (error, crypted_passwd){
        if (error || crypted_passwd === null) {
            connection.logdebug(exports, "Error: " +error.message);
            return cb(false);
        }

        var offset = crypted_passwd.indexOf("$", 3);     // find end of the salt, skip hash based identification
        var pwSalt = crypted_passwd.substr(3, (offset -3));
        var hashed = cryptmd5.cryptMD5(passwd, pwSalt);

        if (hashed === crypted_passwd) {
            return cb(true);
        }

        return cb(false);
    });
};