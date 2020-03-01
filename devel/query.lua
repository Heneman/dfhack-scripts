-- Query is a script useful for finding and reading values of data structure fields. Purposes will likely be exclusive to writing lua script code.
-- Written by Josh Cooper(cppcooper) on 2017-12-21, last modified: 2020-02-23
local utils=require('utils')
local validArgs = utils.invert({
 'help',
 'unit',
 'item',
 'tile',
 'table',
 'query',
 'depth',
 'keydepth',
 'listfields',
 'listkeys',
 'querykeys',
 'getfield',
 'debug'
})
local args = utils.processArgs({...}, validArgs)
local help = [====[

devel/query
===========
Query is a script useful for finding and reading values of data structure fields.
Purposes will likely be exclusive to writing lua script code.

This script can recursively search tables for fields matching the input query.
The root table can be specified explicitly, or a unit can be searched instead.
Any matching fields will be printed alongside their value.
If a match has sub-fields they too can be printed.

The script considers sub-fields to be keys, and parents of them to be fields.
This distinction is made to allow for searching for a particular keys inside
particular fields. You can also limit the depth of recursion used to find both
fields and keys to help filter information out of the output.

When performing table queries, use dot notation to denote sub-tables.
The script has to parse the input string and separate each table.

Note 1: This script walks recursively through data structures, some fields and keys
 are not printed, or delved into to avoid flooding the console and to
 avoid crashing the game and dfhack. For more information see the code.

Note 2: Most of the focus was given to finding and printing useful fields/keys,
 things most of us can probably just read and understand.
 So situations where the data is probably not user friendly tend to be skipped,
 but I can't deal with everything.

Warning: Careful what you run, you may need to kill Dwarf Fortress before you
 run out of memory and your computer grinds to a halt.. or you may just need
 to sit and wait for 10 minutes for the query to finish printing. The default
 recursion values should prevent this, but no guarantees, and if you increase
 the defaults all bets are off.

Examples:
  [DFHack]# devel/query -table df -query dead
  [DFHack]# devel/query -table df.global.ui.main -depth 0
  [DFHack]# devel/query -table df.profession -querykeys WAR
  [DFHack]# devel/query -unit -query STRENGTH
  [DFHack]# devel/query -unit -query physical_attrs -listkeys
  [DFHack]# devel/query -unit -getfield id

-~~~~~~~~~~~~
selection options:

  These options are used to specify where the query will run,
  or specifically what key to print inside a unit.

    unit               - Selects the highlighted unit

    item               - Selects the highlighted item.

    tile               - Selects the highlighted tile's block and then attempts
                         to find the tile, and perform your queries on it.

    table <value>      - Selects the specified table (ie. 'value').
                         Must use dot notation to denote sub-tables.
                         (eg. -table df.global.world)

    getfield <value>   - Gets the specified key from the selected unit.
                         Note: Must use the 'unit' option and doesn't support the
                         options below. Useful if there would be several matching
                         fields with the key as a substring (eg. 'id')

-~~~~~~~~~~~~
query options:

    query <value>      - Searches the selection for fields with substrings matching
                         the specified value.

    querykeys <value>  - Lists only keys matching the specified value.

    listfields         - Lists most~ fields found in the query target.
    listkeys           - Lists most~ keys in most~ fields matching any query.

    depth <value>      - Limits the field recursion depth (default: 100)
    keydepth <value>   - Limits the key recursion depth (default: 3)

command options:

    help               - Prints this help information.

]====]
depth=nil
keydepth=nil
bprintfields=(args.query or args.listfields or args.depth) and true or false
bprintkeys=(args.querykeys or args.listkeys or args.keydepth) and true or false
if args.depth then
    depth = tonumber(args.depth)
    if not depth then
        qerror(string.format("Must provide a number with -depth"))
    end
else
    depth = 100
    args.depth = depth
end
if args.keydepth then
    keydepth = tonumber(args.keydepth)
    if not keydepth then
        qerror(string.format("Must provide a number with -keydepth"))
    end
else
    keydepth = 2
    args.keydepth = keydepth
end
space_field="   "
space_key="     "
fN=0
--kN=25

--thanks goes mostly to the internet for this function. thanks internet you da real mvp
function safe_pairs(item, keys_only)
    if keys_only then
        local mt = debug.getmetatable(item)
        if mt and mt._index_table then
            local idx = 0
            return function()
                idx = idx + 1
                if mt._index_table[idx] then
                    return mt._index_table[idx]
                end
            end
        end
    end
    local ret = table.pack(pcall(function() return pairs(item) end))
    local ok = ret[1]
    table.remove(ret, 1)
    if ok then
        return table.unpack(ret)
    else
        return function() end
    end
end

function debugf(level,...)
    if args.debug and level <= tonumber(args.debug) then
        str=string.format(" #  %s",select(1, ...))
        for i = 2, select('#', ...) do
            str=string.format("%s\t%s",str,select(i, ...))
        end
        print(str)
    end
end

cur_depth = -1
N=0
function Query(t, query, parent)
    cur_depth = cur_depth + 1
    if not depth or (depth and cur_depth <= depth) then
        if not parent then
            parent = ""
        end
        for k,v in safe_pairs(t) do
            -- avoid infinite recursion
            if not tonumber(k) and (type(k) ~= "table" or depth) and not string.find(tostring(k), 'script') then
                --print(parent .. "." .. k)
                if not string.find(parent, tostring(k)) then
                    if parent then
                        Query(v, query, parent .. "." .. tostring(k))
                    else
                        Query(v, query, k)
                    end
                end
            else
                if not tonumber(k) then
                    debugf(4,"Query blocked, queried field was not a number")
                elseif (type(k) ~= "table" or depth) then
                    debugf(4,"Query blocked, queried field was not a table")
                elseif not string.find(tostring(k), 'script') then
                    debugf(4,"Query blocked, queried field was a script")
                end
            end
            debugf(6,"main",parent,k,args.query)
            if not args.query or string.find(tostring(k), args.query) then
                debugf(5,"main",parent,tostring(k),args.query)
                if bprintfields and not args.querykeys then
                    debugf(5,"main->print_field")
                    print_field(string.format("%s.%s",parent,tostring(k)),v,true)
                    if bprintkeys then
                        debugf(5,"main->print_keys (without parents)")
                        print_keys(string.format("%s.%s",parent,tostring(k)),v,false)
                    end
                elseif bprintkeys then
                    debugf(5,"main->print_keys (with parents)")
                    if not (args.query or args.querykeys) then
                        print_field(string.format("%s.%s",parent,tostring(k)),v,true)
                        print_keys(string.format("%s.%s",parent,tostring(k)),v,false)
                    else
                        print_keys(string.format("%s.%s",parent,tostring(k)),v,true)
                    end
                else
                    qerror("You either forgot to provide a query of some form, or there is malformed logic at play.")
                end
            end
        end
    else
        debugf(4,"Query blocked, max depth reached")
    end
    cur_depth = cur_depth - 1
end

function print_field(field,v,ignoretype)
    debugf(5,"print_field")
    if ignoretype or not (type(v) == "userdata") then
        --print("Field","."..field)
        field=string.format("%s: ",tostring(field))
        cN=string.len(field)
        fN = cN >= fN and cN or fN
        fN = fN >= 90 and 90 or fN
        f="%-"..(fN+5).."s"
        print(space_field .. string.gsub(string.format(f,field),"   "," ~ ") .. tostring(v))
    end
end

bprinted=false
function print_key(k,v,bprint,parent,v0)
    debugf(3,"print_key")
    if not args.querykeys or string.find(tostring(k), args.querykeys) or string.find(tostring(parent), args.querykeys) then
        debugf(2,tostring(k),v,bprint,parent,v0)
        if not bprinted and bprint then
            debugf(1,"print_key->print_field")
            print_field(parent,v0,true)
            bprinted=true
        end
        key=string.format("%s: ",tostring(k))
        -- cN=string.len(key)
        -- kN = cN >= kN and cN or kN
        -- kN = kN >= 90 and 90 or kN
        -- f="%-"..(kN+5).."s"
        indent=""
        for i=1,cur_keydepth do
            indent=string.format("%s ",indent)
        end
        print(indent .. space_key .. string.format("%s",key) .. tostring(v))
    end
end

function isDefinitelyNotHumanReadable(k,v)
    if type(k) == "number" and (type(v) == "userdata" or type(v) == "number" or type(v) == "boolean" or type(v) == "nil") then
        return true
    end
    return false
end

cur_keydepth = -1
function print_keys(parent,v,bprint)
    cur_keydepth = cur_keydepth + 1
    if not keydepth or (keydepth and cur_keydepth <= keydepth) then
        bprinted=false
        if type(v) == "table" and v._kind == "enum-type" then
            debugf(4,"keys.A")
            for i,e in ipairs(v) do
                if isDefinitelyNotHumanReadable(k2,v2) then
                    debugf(0,"keys.A.break")
                    break
                end
                if not args.querykeys or string.find(tostring(v[i]), args.querykeys) then
                    if not bprinted and bprint then
                        print_field(parent,v,true)
                        bprinted=true
                    end
                    print(string.format("%s%-3d %s",space_key,i,e))
                end
            end
        elseif type(v) == "userdata" then
            debugf(4,"keys.B",tostring(v),type(v))
            if args.tile then
                --too much information, and it seems largely useless
                --todo: figure out an even better way to prune useless info OR add option (option suggestion: -floodconsole)
                if v._kind == "container" then
                    debugf(4,"keys.B.a.0")
                    for ix,v2 in ipairs(v) do
                        if ix == x and type(v2) == "userdata" and v2._kind == "container" then
                            for iy,v3 in ipairs(v2) do
                                if iy == y then
                                    debugf(4,"keys.B.a.1")
                                    if type(v3) == "userdata" then
                                        for k4,v4 in pairs(v3) do
                                            print_key(k4,v4,true,parent,v3)
                                        end
                                    elseif type(v3) ~= nil and (not args.querykeys or string.find(tostring(k3),args.querykeys)) then
                                        print_field(string.format("%s[%d][%d]",parent,x,y),v3,true)
                                    end
                                end
                            end
                        end
                    end
                end
            elseif not string.find(tostring(v),"userdata") and v._kind ~= "bitfield" then
                --crash fix: string.find(...,"userdata") it seems that the crash was from hitting some ultra-primitive type (void* ?)
                    --Not the best solution, but if duct tape works, why bother with sutures....
                debugf(3,"keys.B.a.0", v, type(v))
                for k2,v2 in safe_pairs(v) do
                    if isDefinitelyNotHumanReadable(k2,v2) then
                        debugf(0,"keys.B.a.break")
                        break
                    end
                    debugf(3,"keys.B.a.1")
                    print_key(k2,v2,bprint,parent,v)
                    print_keys(parent..tostring(k2),v2,false)
                end
            end
        else
            debugf(4,"keys.C",parent,v,type(v),bprint,bprinted)
            for k2,v2 in safe_pairs(v) do
                if isDefinitelyNotHumanReadable(k2,v2) then
                    debugf(0,"keys.C.break")
                    break
                end
                debugf(3,"keys.C.1")
                print_key(k2,v2,bprint,parent,v)
                print_keys(parent..tostring(k2),v2,false)
            end
        end
    end
    cur_keydepth = cur_keydepth - 1
end

function parseTableString(str)
    tableParts = {}
    for word in string.gmatch(str, '([^.]+)') do --thanks stack overflow
        table.insert(tableParts, word)
    end
    curTable = nil
    for k,v in pairs(tableParts) do
      if curTable == nil then
        if _G[v] ~= nil then
            curTable = _G[v]
        else
            qerror("Table" .. v .. " does not exist.")
        end
      else
        if curTable[v] ~= nil then
            curTable = curTable[v]
        else
            qerror("Table" .. v .. " does not exist.")
        end
      end
    end
    return curTable
end

function parseKeyString(t,str)
    curTable = t
    keyParts = {}
    for word in string.gmatch(str, '([^.]+)') do --thanks stack overflow
        table.insert(keyParts, word)
    end
    for k,v in pairs(keyParts) do
        if curTable[v] ~= nil then
            curTable = curTable[v]
        else
            qerror("Table" .. v .. " does not exist.")
        end
    end
    return curTable
end

pos = nil
x = nil
y = nil
block = nil
local selection = nil
if args.help then
    print(help)
elseif args.table then
    local t = parseTableString(args.table)
    if args.query ~= nil then
        Query(t, args.query, args.table)
    else
        Query(t, '', args.table)
    end
elseif args.unit or args.item or args.tile then
    info=""
    if args.unit then
        selection = dfhack.gui.getSelectedUnit()
        info="unit"
    elseif args.item then
        selection = dfhack.gui.getSelectedItem()
        info="item"
    else
        pos = copyall(df.global.cursor)
        x = pos.x%16
        y = pos.y%16
        block = dfhack.maps.ensureTileBlock(pos.x,pos.y,pos.z)
        selection = block
        info="tile"
    end
    info_selection="selected-"..info
    msg=string.format("Selected %s is null. Invalid selection.",info)
    debugf(0,selection,info_selection,info)
    if args.getfield then
        X=parseKeyString(selection,args.getfield)
        if type(X) == 'number' or type(X) == "string" or type(X) == "boolean" or type(X) == "nil" then
            print(info_selection..args.getfield..": ",parseKeyString(selection,args.getfield))
        elseif args.listkeys or args.querykeys or args.keydepth or args.query or args.depth then
            Query(parseKeyString(selection,args.getfield),args.query,info_selection.."."..args.getfield)
        else
            print(info_selection..args.getfield..": ",parseKeyString(selection,args.getfield))
        end
    else
        if selection == nil then
            qerror(msg)
        elseif args.query ~= nil then
            Query(selection, args.query, info_selection)
        else
            Query(selection, '', info_selection)
        end
    end
else
    print(help)
end