# Class: stash
#
# This module manages Atlassian Stash
#
# Parameters:
#
# Actions:
#
# Requires:
#
#	Class['tomcat']
#   Tomcat::Webapp[$username]
#
#   See https://github.com/jurgenlust/puppet-tomcat
#
# Sample Usage:
#
class stash (
	$user = "stash",	
	$database_name = "stash",
	$database_driver = "org.postgresql.Driver",
	$database_driver_jar = "postgresql-9.1-902.jdbc4.jar",
	$database_driver_source = "puppet:///modules/stash/db/postgresql-9.1-902.jdbc4.jar",
	$database_url = "jdbc:postgresql://localhost/stash",
	$database_user = "stash",
	$database_pass = "stash",
	$number = 4,
	$version = "1.1.1",
	$contextroot = "stash",
	$webapp_base = "/srv"
){
	include java7

# configuration
	$stash_build = "atlassian-stash-${version}"	
	$tarball = "${stash_build}.tar.gz"
	$download_dir = "/tmp"
	$downloaded_tarball = "${download_dir}/${tarball}"
	$download_url = "http://www.atlassian.com/software/stash/downloads/binary/${tarball}"
	$stash_dir = "${webapp_base}/${user}"
	$stash_home = "${stash_dir}/stash-home"
	
	$webapp_context = $contextroot ? {
	  '/' => '',	
      '' => '',
      default  => "/${contextroot}"
    }
    
    $webapp_war = $contextroot ? {
    	'' => "ROOT.war",
    	'/' => "ROOT.war",
    	default => "${contextroot}.war"	
    }
    
	file { $stash_home:
		ensure => directory,
		mode => 0755,
		owner => $user,
		group => $user,
		require => Tomcat::Webapp::User[$user],
	}

# We need Git
	if (!defined(Package["git"])) {
		package { 'git':
			ensure => latest,
		}
	}

# Download the Stash archive
	exec { "download-stash":
		command => "/usr/bin/wget -O ${downloaded_tarball} ${download_url}",
		require => Tomcat::Webapp::User[$user],
		creates => $downloaded_tarball,
		timeout => 1200,	
		notify => Exec['extract-stash']
	}
	
	file { $downloaded_tarball :
		require => Exec["download-stash"],
		ensure => file,
	}
	
# Extract the Stash archive
	exec { "extract-stash":
		command => "/bin/tar -xvzf ${tarball} && mv ${stash_build}/atlassian-stash.war ${stash_dir}/tomcat/webapps/${webapp_war}",
		cwd => $download_dir,
		user => $user,
		creates => "${stash_dir}/tomcat/webapps/${webapp_war}",
		timeout => 1200,
		require => [
			File[$downloaded_tarball],
			Tomcat::Webapp::Tomcat[$user],	
		],
		notify => Tomcat::Webapp::Service[$user],	
	}

# the Stash war file
	file { 'stash-war' :
		path => "${stash_dir}/tomcat/webapps/${webapp_war}", 
		ensure => file,
		owner => $user,
		group => $user,
		require => Exec["extract-stash"],
	}
	
# the database driver jar
	file { 'stash-db-driver':
		path => "${stash_dir}/tomcat/lib/${database_driver_jar}", 
		source => $database_driver_source,
		ensure => file,
		owner => $user,
		group => $user,
		require => Tomcat::Webapp::Tomcat[$user],
	}
	
	file { 'stash.properties' :
		path => "${stash_home}/stash.properties",
		content => template('stash/stash.properties.erb'),
		ensure => file,
		owner => $user,
		group => $user,
		require => File[$stash_home],
	}    
	
	Class["java7"] -> Class["tomcat"]

# the Tomcat instance
	tomcat::webapp { $user:
		username => $user,
		webapp_base => $webapp_base,
		number => $number,
		java_opts => "-server -Xms128m -Xmx512m -XX:MaxPermSize=256m -Djava.awt.headless=true -Dstash.home=${stash_home} -Dfile.encoding=utf-8",
		description => "Atlassian Stash",
		service_require => [
			File['stash-war'],
			File['stash-db-driver'],
			File['stash.properties']
		],
		require => [
			Class["tomcat"],
			Package['git'],
			Class["java7"],	
		]
	}

		
}
