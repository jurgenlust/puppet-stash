include tomcat
include postgres

postgres::user { 'stash_user': 
	username => 'stash_user',
	password => 'stash_secret_password',
}

postgres::db { 'stashdb':
	name => 'stashdb',
	owner => 'stash_user'
}

class { "stash": 
	user => "stash", #the system user that will own the Stash Tomcat instance
	database_name => "stashdb",
	database_driver => "org.postgresql.Driver",
	database_driver_jar => "postgresql-9.1-902.jdbc4.jar",
	database_driver_source => "puppet:///modules/stash/db/postgresql-9.1-902.jdbc4.jar",
	database_url => "jdbc:postgresql://localhost/stashdb",
	database_user => "stash_user",
	database_pass => "stash_secret_password",
	number => 4, # the Tomcat http port will be 8480
	version => "1.0.3", # the Stash version
	contextroot => "/",
	webapp_base => "/opt", # Stash will be installed in /opt/stash
	require => [
		Postgres::Db['stashdb'],
		Package['tomcat6']
	],
}

	exec {
		"apt-update" :
			command => "/usr/bin/apt-get update",
	}
	Exec["apt-update"] -> Package <| |>
