message_text_font("courier new",10,$ffffff,"")
message_size(500,-1)
show_message("#  gm82upx#  =======#  Version 1.1##Written by renex##This program can compress games made in Game Maker:##- 8.0#- 8.1.91#- 8.1.141#- 8.2##Compression saves filesize and curbs simple decompilation.##Remember however, that the Game Data metafile cannot be compressed, so the gains are only relative to Game Runner compression.")

garbage_offset_address_800=1329856
garbage_offset_address_91a=2034771
garbage_offset_address_91b=2034980
garbage_offset_address_141=2256123
garbage_offset_800=2000000
garbage_offset_810=3800004
garbage_offset_820=3560004

upx_offset=992

temp_file='tmp.exe'
if (parameter_count()) work_file=parameter_string(1)
else work_file=get_open_filename('Game Maker Game|*.exe','')
backup_file=filename_change_ext(work_file,'.bkp')

if (!file_exists(work_file)) {game_end() exit}

//read runner
b=buffer_create()
buffer_load(b,work_file)
game_size=buffer_get_size(b)

//look for upx signature
buffer_set_pos(b,upx_offset)
if (buffer_read_data(b,3)=="UPX") {
    show_message('Detected UPX packing.##Game is already compressed.')
    game_end()
    exit
}

//check version
if (game_size<garbage_offset_800) {
    show_message('File is too small to be a GM8 game.##Very confused right now.')
    game_end()
    exit
}

buffer_set_pos(b,garbage_offset_address_800)
garbage_offset=buffer_read_u32(b)
if (garbage_offset=garbage_offset_800) {
    mode=80
    show_message('Detected GM 8.0!')
} else {
    if (game_size<garbage_offset_810) {
        show_message('File is too small to be a GM81 game.##Very confused right now.')
        game_end()
        exit
    }
    buffer_set_pos(b,garbage_offset_address_91a)
    garbage_offset=buffer_read_u32(b)
    if (garbage_offset=garbage_offset_810) {
        mode=91
        show_message('Detected GM 8.1.91!')
    } else {
        buffer_set_pos(b,garbage_offset_address_141)
        garbage_offset=buffer_read_u32(b)
        if (garbage_offset=garbage_offset_810) {
            mode=141
            show_message('Detected GM 8.1.141!')
        } else if (garbage_offset=garbage_offset_820) {
            mode=141
            show_message('Detected GM 8.2!')
        } else {
            show_message("This doesn't seem to use a supported version of Game Maker and can't be compressed.")
            game_end()
            exit
        }
    }
}

draw_clear($404040)
draw_text(10,10,"Working...")
screen_refresh()

runner=buffer_create()
buffer_copy_part(runner,b,0,garbage_offset)

//upx runner
buffer_save(runner,temp_file)
execute_program_silent(temp_directory+'\upx.exe --lzma '+temp_file)
sleep(100)

//find compressed runner size
upx=buffer_create()
buffer_load(upx,temp_file)
upx_length=buffer_get_size(upx)-1
buffer_set_pos(upx,upx_length)
do {
    upx_length-=8
    buffer_set_pos(upx,upx_length)
    d=buffer_read_u64(upx)
} until (d)
upx_length=ceil((upx_length+8)/4096)*4096

//patch the garbage addresses
if (mode=80) {
    buffer_set_pos(runner,garbage_offset_address_800)
    buffer_write_u32(runner,upx_length)
}
if (mode=91) {
    buffer_set_pos(runner,garbage_offset_address_91a)
    buffer_write_u32(runner,upx_length)
    buffer_set_pos(runner,garbage_offset_address_91b)
    buffer_write_u32(runner,upx_length)
}
if (mode=141) {
    buffer_set_pos(runner,garbage_offset_address_141)
    buffer_write_u32(runner,upx_length)
}


//upx runner again after patching addresses
buffer_save(runner,temp_file)
execute_program_silent(temp_directory+'\upx.exe --lzma '+temp_file)
sleep(100)

//get final upx runner
buffer_load(runner,temp_file)
buffer_set_size(runner,upx_length)

//append game data
buffer_copy_part(runner,b,garbage_offset,game_size-garbage_offset)

//create output file
file_rename(work_file,backup_file)
sleep(10)
buffer_save(runner,work_file)
final_size=buffer_get_size(runner)

file_delete(temp_file)

show_message("Compression finished.##"+string(game_size)+" -> "+string(final_size)+"#Total savings: "+string(100-(final_size/game_size)*100)+"%.")
game_end()
