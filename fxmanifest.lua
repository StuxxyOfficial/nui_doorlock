fx_version 'cerulean'
games { 'gta5' }

version '2.0.1'
description 'https://github.com/thelindat/nui_doorlock'
versioncheck 'https://raw.githubusercontent.com/thelindat/nui_doorlock/main/fxmanifest.lua'

shared_script '@es_extended/imports.lua'

server_scripts {
	'config.lua',
	'configs/**/*.lua',
	'server/main.lua'
}

client_scripts {
	'config.lua',
	'client/main.lua'
}

dependency 'es_extended'

ui_page {
	'html/door.html',
}

files {
	'html/door.html',
	'html/main.js', 
	'html/style.css',

	'html/sounds/*.ogg',
}
