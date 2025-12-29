fx_version 'cerulean'
game 'gta5'

author 'Meiku'
description 'Level System Yo!'
lua54 'yes'

shared_scripts {
  '@ox_lib/init.lua',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/*.lua'
}

files {
  'config/**.lua',
  'web/dist/**.js',
  'web/dist/**.css',
  'web/dist/index.html'
}