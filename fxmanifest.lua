fx_version 'cerulean'
game 'gta5'

author 'DonHulieo'
description 'Don\'s Warehousing System with Forklift Logistics for FiveM'
version '1.3.1'
url 'https://github.com/DonHulieo/don-forklift'

shared_script '@duff/shared/import.lua'

server_script 'server/main.lua'

client_script 'client/main.lua'

files {'shared/config.lua', 'server/config.lua'}

dependencies {'/onesync', 'duff', 'iblips'}

lua54 'yes'
