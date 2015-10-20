var mysql = require('mysql');
var DSN = require('./dsn');

exports.get_user_parts = function(user, next, connection, cb) {
    var name   = user.split("@")[0];
    var domain = user.split("@")[1] || null;
    //@todo fails when not in rcpt_list... shouldnt be used then in the first place??
    if (domain === null){
        connection.logerror(exports,"Quota: Wrong login format for user ", user);
        return next(DENYSOFT);
    }

    cb(name, domain);
};

exports.get_user_quota = function(user, next, connection, cb) {
    var query = null;
    var notes = server.notes.quota_check;

    notes.pool.connect(function(err, mysql) {
        if (err) {
            connection.logerror(exports, "MySQL error: " + err.message);
            return next(DENYSOFT);
        }

        exports.get_user_parts(user, next, connection, function(name, domain){
            query = notes.config.main.quota_query;
            query = query.replace(/%d/g, domain).replace(/%n/g, name).replace(/%u/g, user);

            connection.logdebug(exports, "exec query: " + query);

            mysql.query(query, [user], function(err, results) {
                if (err) {
                    connection.logerror(exports, "MySQL error: " + err.message);
                    return next(DENYSOFT);
                }

                if (results && results.length > 0) {
                    cb(null, results[0]);
                } else {
                    cb(null);
                }
            });

        });

    });
};

exports.init_mysql = function(connection) {
    if (!server.notes.quota_check || !server.notes.quota_check.pool) {
        var config = this.config.get("quota.check.ini", {
            host: "localhost",
            port: 3306,
            char_set: 'UTF8_GENERAL_CI',
            ssl: false,
            quota_query: "SELECT limit, used FROM WHERE name = ?"
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

                return
            }

            return callback(null, self.connection);
        };

        server.notes.quota_check = {
            config: config,
            pool  : {connect: connect}
        };
    }

    connection.logdebug(exports, 'MySQL host="' + server.notes.quota_check.config.main.host + '"' +
            ' port="' + server.notes.quota_check.config.main.port + '"' +
            ' user="' + server.notes.quota_check.config.main.user + '"' +
            ' database="' + server.notes.quota_check.config.main.database+ '"');
};

exports.hook_mail = function (next, connection, params) {
    var email = params[0].original.substr(1, params[0].original.length -2);   // input = <name@domain.tld>

    this.init_mysql(connection);
    this.get_user_quota(email, next, connection, function(error, user){
        if (error){
            connection.logerror(exports, "Quota error: " + error);
            return next(DENYSOFT);
        }

        //@todo quota should only work with numeric values...
        connection.logdebug(exports, "Quota of user ", email, " limit=\""+ user.quota +" M\" used=\""+ user.bytes +" bytes\"");

        var usedQuotaInM = (user.bytes / 1048576).toFixed(1);
        if (usedQuotaInM > user.quota) {
            return next(DENY, DSN.mbox_full());
        }

        return next();
    });
};