require "Cocos2d"
require "Cocos2dConstants"
require "misc"
require "anysdkConst"
local cfg = require "config"

local winSize = cc.Director:getInstance():getWinSize()
print('winSize:',winSize.width,winSize.height)
local GUI_TAG = 101
local SPRITE_TAG = 10000
local LABEL_NODE_TAG = 9999
local BLINK_TAG =9998
local num_cnt = 0
local total_score = 0
local gameMap ={}
local gameMapNode={}
local move_effect = 1
local merge_effect = 2
local clear_effect = 3
local schedulerID = nil
local bannerShowTime = 30
local intervalTime = 60
local schedulerCnt = 0

local effect_map = {
    [move_effect] = 'move',
    [merge_effect] = 'merge',
    [clear_effect] = 'clear',
}
local debug = 0
local cclog = function(...)
    if debug > 0 then
        print(string.format(...))
    end
end

local agent = nil
local ads_plugin = nil

local function initSDK( ... )
    agent = AgentManager:getInstance()
    --init
    local appKey = "16D97970-5F8B-5B5B-10A8-6968AF55C831";
    local appSecret = "3ab964c2dd195b1753cdbc999912e726";
    local privateKey = "E8CC5B50BFE0612482D266A7700994AD";
    local oauthLoginServer = "http://oauth.anysdk.com/api/OauthLoginDemo/Login.php";
    agent:init(appKey,appSecret,privateKey,oauthLoginServer)
    --load
    agent:loadALLPlugin()
    ads_plugin = agent:getAdsPlugin()
    cclog('ads_plugin:',ads_plugin)

    local function onAdsListener( code,msg )
        cclog("on ads action listener.")
        if type(code) == "number" then
            cclog("show ads result code:"..code)
            cclog('show ads result message:'..msg)
        else
            cclog("get ads points:" .. msg)
        end
    end
    ads_plugin:setAdsListener(onAdsListener)
    if  ads_plugin:isAdTypeSupported(AdsType.AD_TYPE_BANNER) then
        -- ads_plugin:showAds(AdsType.AD_TYPE_BANNER)
    else
        cclog('ads_plugin was not support')
    end
end

local function showAds( ... )
    if ads_plugin and ads_plugin:isAdTypeSupported(AdsType.AD_TYPE_BANNER) then
        cclog('~~~~~ showAds')
        ads_plugin:showAds(AdsType.AD_TYPE_BANNER)
    else
        cclog('ads_plugin was not support')
    end
end

local function hideAds( ... )
    if ads_plugin then
        ads_plugin:hideAds(AdsType.AD_TYPE_BANNER)
    end
end

local GameScene = class("GameScene",function()
    return cc.Scene:create()
end)

function GameScene.create()
    local scene = GameScene.new()
    initSDK()
    math.randomseed(tostring(os.time()):reverse():sub(1, 6))
    scene:addChild(scene:LoadGUI(),0,GUI_TAG)
    return scene
end


function GameScene:ctor()
    self.visibleSize = cc.Director:getInstance():getVisibleSize()
    self.origin = cc.Director:getInstance():getVisibleOrigin()
end

function GameScene:getRandomNumber()
    local randList = {1,2,4,8}
    cclog('randList len:',#randList)
    local num = math.random(4)
    return randList[num]
    
end

function GameScene:randNumber( ... )
    local randList = {}
    for i=1,cfg.gw do
        if gameMap[1][i] == 0 then
            table.insert(randList,i)
        end
    end
    for k,v in pairs(randList) do
        cclog('### randList:',k,v)
    end
    local _randIndex = math.random(#randList)
    cclog('_randIndex:',_randIndex,'pos:',randList[_randIndex])
    local rand_pos = randList[_randIndex]
    num_cnt = num_cnt + 1
    if num_cnt >= 0x7FFFFFFFF then
        num_cnt = 0 
    end
    local rand_num = self:getRandomNumber()
    gameMap[1][rand_pos] = rand_num
    gui.curSelX = 1
    
    gui.curSelY = rand_pos
    cclog('1 gui.curSelX:',gui.curSelX)
    cclog('1 gui.curSelY:',gui.curSelY)
    cclog('value:',gameMap[gui.curSelX][gui.curSelY])
    cclog('rand new number:',rand_num)
    local label_bg = cc.Sprite:create('demo/numbers_bg.png')
    local bgsize = label_bg:getContentSize()
    local num_str = tostring(rand_num)
    local randNumLabel = cc.Label:createWithTTF(num_str,"fonts/BRLNSR.TTF",
        56-string.len(num_str)*6 > 15 and 56-string.len(num_str)*6 or 15,bgsize,cc.TEXT_ALIGNMENT_CENTER,
        cc.VERTICAL_TEXT_ALIGNMENT_CENTER)
    if randNumLabel == nil then
        cclog('randNumLabel is nil')
        do return end
    end
    randNumLabel:setColor(cc.c3b(0,0,0))
    randNumLabel:setPosition(cc.p(bgsize.width/2,bgsize.height/2))
    
    label_bg:addChild(randNumLabel,0,123)
    gui:getChildByTag(LABEL_NODE_TAG):addChild(label_bg,132,SPRITE_TAG + num_cnt)
    -- label_bg:setAnchorPoint(cc.p(0,0))
    label_bg:setPosition(cc.p(gui.Array_Pos_X[gui.curSelY], gui.Array_Pos_Y[gui.curSelX]))
    local blink = cc.Blink:create(1.5,1)
    local rf = cc.RepeatForever:create(cc.Sequence:create(blink))
    rf:setTag(BLINK_TAG)
    label_bg:runAction(rf)
    cclog('2 gui.curSelX:',gui.curSelX)
    cclog('2 gui.curSelY:',gui.curSelY)
    cclog('value:',gameMap[gui.curSelX][gui.curSelY])
end

function GameScene:initMap( ... )
    local score_ = misc.getScore()
    total_score = 0
    gui:getChildByName('score'):setString('0')
    gui:getChildByName('his_score'):setString(tostring(score_))
    local labelLayer = gui:getChildByTag(LABEL_NODE_TAG)
    if labelLayer then
        labelLayer:removeAllChildren()
    end
    for i=1, cfg.gh do
        gameMap[i]=setmetatable({},{__mode="v"})
        gameMapNode[i]=setmetatable({},{__mode='v'})
        for j=1 , cfg.gw do
            gameMap[i][j] = 0
            gameMapNode[i][j]=nil
        end
    end
end

function GameScene:startGame()
    -- cclog('game start')
    self:initMap()
    self:randNumber()
end

function GameScene:showEndLayer( ... )
    -- cclog('game end')
    local score_ = misc.getScore()
    if total_score > tonumber(score_) then
        misc.setScore(total_score)
        misc.saveScore()
    end
    local size = gui:getContentSize()
    local endLayer = cc.LayerColor:create(cc.c4b(0,0,0,128),size.width,size.height)
    gui:addChild(endLayer,256)
    local function onTouchBegan(touch, event)
        return true
    end

    local listener = cc.EventListenerTouchOneByOne:create()
    listener:setSwallowTouches(true)
    -- 注册两个回调监听方法
    listener:registerScriptHandler(onTouchBegan,cc.Handler.EVENT_TOUCH_BEGAN )
    local eventDispatcher = endLayer:getEventDispatcher()-- 时间派发器
    -- 绑定触摸事件到层当中
    eventDispatcher:addEventListenerWithSceneGraphPriority(listener, endLayer)

    local gameOverBg = cc.Sprite:create('demo/bg_gameover.png')
    endLayer:addChild(gameOverBg)
    gameOverBg:setPosition(size.width/2,size.height/2)
    local bgSize = gameOverBg:getContentSize()

    local pBackgroundButton            = cc.Scale9Sprite:create("demo/btn_tryagain_normal.png")
    local pBackgroundHighlightedButton = cc.Scale9Sprite:create("demo/btn_tryagain_selected.png")
    local playAgainBtn = cc.ControlButton:create()
    playAgainBtn:setBackgroundSpriteForState(pBackgroundButton, cc.CONTROL_STATE_NORMAL)
    playAgainBtn:setBackgroundSpriteForState(pBackgroundHighlightedButton,cc.CONTROL_STATE_HIGH_LIGHTED)
    gameOverBg:addChild(playAgainBtn,1)
    playAgainBtn:setPreferredSize(cc.size(200,100))
    playAgainBtn:setPosition(cc.p(bgSize.width/2, bgSize.height*0.4))
    playAgainBtn:registerControlEventHandler(function ( ... )
        self:startGame()
        endLayer:removeFromParent()
    end,cc.CONTROL_EVENTTYPE_TOUCH_UP_INSIDE)
    local btnSize = playAgainBtn:getContentSize()
    local playAgainSp = cc.Sprite:create('demo/tryagain.png')
    playAgainBtn:addChild(playAgainSp)
    
    playAgainSp:setPosition(cc.p(btnSize.width/2, btnSize.height/2))
end

function GameScene:createNoTouchLayer( ... )
    local layer = cc.Layer:create()
    layer:setContentSize(winSize)

    local function onTouchBegan(touch, event)
        return true
    end

    local listener = cc.EventListenerTouchOneByOne:create()
    listener:setSwallowTouches(true)
    -- 注册两个回调监听方法
    listener:registerScriptHandler(onTouchBegan,cc.Handler.EVENT_TOUCH_BEGAN )
    local eventDispatcher = layer:getEventDispatcher()-- 时间派发器
    -- 绑定触摸事件到层当中
    eventDispatcher:addEventListenerWithSceneGraphPriority(listener, layer)

    return layer
end

function GameScene:LoadGUI()
    --    local layer = cc.LayerColor:create(cc.c4b(255,0,0,128))
    gui = ccs.GUIReader:getInstance():widgetFromJsonFile("demo/demo_1.json")

    local score_ = misc.getScore()
    gui:getChildByName('score'):setString('0')
    gui:getChildByName('his_score'):setString(tostring(score_))

    gui.Array_Pos_X = {}
    gui.Array_Pos_Y = {}
    for i=1,cfg.gw do
        local tmp = gui:getChildByName('matrix_x_'..i)
        local x,y = tmp:getPosition()
        gui.Array_Pos_X[i] = x
        if i == 1 then
            gui.Array_Pos_Y[1] = y
        end
    end

    for i=2,cfg.gh do
        local tmp = gui:getChildByName('matrix_y_'..i)
        local x,y = tmp:getPosition()
        gui.Array_Pos_Y[i] = y
    end
    -- cclog('x pos array:')
    -- for k,v in pairs(gui.Array_Pos_X) do
    --     cclog(k,v)
    -- end
    -- cclog('y pos array:')
    -- for k,v in pairs(gui.Array_Pos_Y) do
    --     cclog(k,v)
    -- end
    local label_node = cc.Layer:create()
    gui:addChild(label_node,0,LABEL_NODE_TAG)

    local function stopAllScheduler()
        if schedulerInterval then
             
            
        end
        
        if schedulerShow then
            cc.Director:getInstance():getScheduler():unscheduleScriptEntry(schedulerShow) 
        end
        schedulerInterval = nil
        schedulerShow = nil
    end
    
    local function tick()
        schedulerCnt = schedulerCnt + 1
        print('schedulerCnt:',schedulerCnt)
        if schedulerCnt == 1 then
        elseif schedulerCnt == 2 then
            showAds()
        elseif schedulerCnt == 3 then
            hideAds()
            schedulerCnt = 0
        else
            schedulerCnt = 0
        end            
    end
    
    local function onEnter( ... )
        if schedulerID == nil then
            schedulerID = cc.Director:getInstance():getScheduler():scheduleScriptFunc(tick, bannerShowTime, false)
        end
    end
    
    local function onExit( ... )
        cc.Director:getInstance():getScheduler():unscheduleScriptEntry(schedulerID)
        schedulerID = nil
    end

    local function onNodeEvent(event)
        if "enter" == event then
            onEnter()
        elseif "exit" == event then
            onExit()
        end
    end

    label_node:registerScriptHandler(onNodeEvent)

    local beginPos = nil
    local function onTouchBegan(touch, event)
        local layer = self:createNoTouchLayer()
        gui:addChild(layer,123,123)
        beginPos = touch:getLocation()
        cclog('beginPos x,y:',beginPos.x,beginPos.y)
        return true
    end

    local function onTouchMoved(touch, event)
        -- cclog('touch moved')
    end

    local function onTouchEnded(touch, event)
        local layer = gui:getChildByTag(123)
        if layer then
            layer:removeFromParent()
        end
        local endPos = touch:getLocation()
        cclog('touch ended,x,y',endPos.x,endPos.y)
        if beginPos.x == endPos.x and beginPos.y == endPos.y then
            do return end
        else
            self:playEffect(move_effect)
            cclog('3 gui.curSelX:',gui.curSelX)
            cclog('3 gui.curSelY:',gui.curSelY)
            if math.abs(beginPos.x - endPos.x) > math.abs(beginPos.y - endPos.y) then
                if beginPos.x > endPos.x then
                    
                    self:moveLeft()
                else
                    self:moveRight()
                end
            else
                if beginPos.y > endPos.y then
                    self:moveDown()
                else
                    -- cclog('move up ignore')
                end
            end
        end
    end

    local listener = cc.EventListenerTouchOneByOne:create()
    listener:setSwallowTouches(true)
    listener:registerScriptHandler(onTouchBegan,cc.Handler.EVENT_TOUCH_BEGAN )
    listener:registerScriptHandler(onTouchMoved,cc.Handler.EVENT_TOUCH_MOVED )
    listener:registerScriptHandler(onTouchEnded,cc.Handler.EVENT_TOUCH_ENDED )
    local eventDispatcher = label_node:getEventDispatcher()
    eventDispatcher:addEventListenerWithSceneGraphPriority(listener, label_node)
    --start game
    self:startGame()

    return gui
end

function GameScene:stopNumberLabelBlink( ... )
    local sp = gui:getChildByTag(LABEL_NODE_TAG):getChildByTag(SPRITE_TAG + num_cnt)
    if sp then
        -- cclog('stop blink action')
        sp:stopActionByTag(BLINK_TAG)
        sp:setVisible(true)
    end
end

function GameScene:moveLeft( ... )
    self:stopNumberLabelBlink()
    cclog('move left gui.curSelX:',gui.curSelX)
    if gui.curSelY <= 1 then do return end end
    if gameMap[gui.curSelX][gui.curSelY - 1] ~= nil then
        -- cclog('-------------befor left begin------------')
        -- for k,v in pairs(gameMap[gui.curSelX]) do
        --     cclog('befor left:',k,v)
        -- end
        -- cclog('--------------befor left end------------')
        if gameMap[gui.curSelX][gui.curSelY - 1] == 0 then
            local layer = self:createNoTouchLayer()
            layer:retain()
            gui:addChild(layer)
            gameMap[gui.curSelX][gui.curSelY - 1] = gameMap[gui.curSelX][gui.curSelY]
            gameMap[gui.curSelX][gui.curSelY] = 0
            gui.curSelY = gui.curSelY - 1
            cclog('gui.curSelX:',gui.curSelX,'y:',gui.curSelY)
            cclog('left:value',gameMap[gui.curSelX][gui.curSelY])
            local sp = gui:getChildByTag(LABEL_NODE_TAG):getChildByTag(SPRITE_TAG + num_cnt)
            if sp then
                sp:runAction(cc.Sequence:create(cc.MoveTo:create(0.2,cc.p(gui.Array_Pos_X[gui.curSelY], gui.Array_Pos_Y[gui.curSelX])),
                    cc.CallFunc:create(
                        function ( ... )
                            layer:removeFromParent()
                            layer:release()
                        end)))
            else
                -- cclog('move left sp is nil')
            end
        else

        end
        -- cclog('-------------after left begin------------')
        -- for k,v in pairs(gameMap[gui.curSelX]) do
        --     cclog('after left:',k,v)
        -- end
        -- cclog('--------------after left end------------')
    end
end

function GameScene:moveRight( ... )
    self:stopNumberLabelBlink()
    cclog('move right gui.curSelX:',gui.curSelX)
    if gui.curSelY >= cfg.gw then do return end end
    if gameMap[gui.curSelX][gui.curSelY + 1] ~= nil then
        -- cclog('-------------befor right begin------------')
        -- for k,v in pairs(gameMap[gui.curSelX]) do
        --     cclog('befor right:',k,v)
        -- end
        -- cclog('--------------befor right end------------')
        if gameMap[gui.curSelX][gui.curSelY + 1] == 0 then
            local layer = self:createNoTouchLayer()
            layer:retain()
            gameMap[gui.curSelX][gui.curSelY + 1] = gameMap[gui.curSelX][gui.curSelY]
            gameMap[gui.curSelX][gui.curSelY] = 0
            gui.curSelY = gui.curSelY + 1
            cclog('gui.curSelX:',gui.curSelX,'y:',gui.curSelY)
            cclog('right:value',gameMap[gui.curSelX][gui.curSelY])
            local sp = gui:getChildByTag(LABEL_NODE_TAG):getChildByTag(SPRITE_TAG + num_cnt)
            if sp then
                sp:runAction(cc.Sequence:create(cc.MoveTo:create(0.2,cc.p(gui.Array_Pos_X[gui.curSelY], gui.Array_Pos_Y[gui.curSelX])),
                    cc.CallFunc:create(
                        function ( ... )
                            layer:removeFromParent()
                            layer:release()
                        end)))
            else
                cclog('move right sp is nil')
            end
        else

        end
        -- cclog('-------------after right begin------------')
        -- for k,v in pairs(gameMap[gui.curSelX]) do
        --     cclog('after right:',k,v)
        -- end
        -- cclog('--------------after right end------------')
    end
end

function GameScene:moveDown( ... )
    self:stopNumberLabelBlink()
    if gui.curSelX >= cfg.gh then do return end end
    if gameMap[gui.curSelX + 1][gui.curSelY] ~= nil then
        -- cclog('-------------befor down begin------------')
        -- for k,v in pairs(gameMap[gui.curSelX]) do
        --     cclog('befor down:',k,v)
        -- end
        -- cclog('--------------befor down end------------')

        local function showNewRandNumber( ... )
            local function isGameEnded( ... )
                for i=1,cfg.gw do
                    if gameMap[1][i] == 0 then
                        do return false end
                    end
                end
                return true
            end

            local layer = gui:getChildByTag(234)
            if layer then
                layer:removeFromParent()
            end
            -- cclog('-------------after down begin------------')
            -- for k,v in pairs(gameMap[gui.curSelX]) do
            --     cclog('after down:',k,v)
            -- end
            -- cclog('--------------after down end------------')
            if isGameEnded() then
                -- cclog('game ended')
                self:showEndLayer()
            else
                 cclog('-------------gameMap Value begin---------')
                 for j=1,cfg.gh do
                     for i=1,cfg.gw do
                       cclog('gamemap[',j,'[',i,']:',gameMap[j][i])
                     end
                 end
                 cclog('------------gameMap Value end---------------')
                self:randNumber()
            end
        end
        local function move( params )
            -- dis, changeToNum, moveNode
            if params.dis == nil then do return end end
            if params.dis == 0 then
                if params.callback then
                    params.callback()
                    do return end
                end
            end
            local sp = nil
            if params.moveNode then
                cclog('111')
                sp = params.moveNode
            else
            cclog('222')
                sp = gui:getChildByTag(LABEL_NODE_TAG):getChildByTag(SPRITE_TAG + num_cnt)
            end
             cclog('### gui.curSelX:',gui.curSelX,'gui.curlSelY:',gui.curSelY)
            if gameMapNode[gui.curSelX][gui.curSelY] ~= nil then
                 cclog('gameMapNode was not nil')
                gameMapNode[gui.curSelX][gui.curSelY]:removeFromParent()
                gameMapNode[gui.curSelX][gui.curSelY] = nil
            end
            gameMapNode[gui.curSelX][gui.curSelY] = sp
             cclog('###### move dis:',params.dis,'changeToNum:',params.changeToNum,' ', params.moveNode)
--             cclog('gui.Array_Pos_X:',gui.Array_Pos_X[gui.curSelY])
--             cclog('gui.Array_Pos_Y:',gui.Array_Pos_Y[gui.curSelX])
--             cclog('sp:getPosition:',sp:getPosition())
            if sp then
                sp:runAction( cc.Sequence:create(
                    cc.MoveTo:create(0.1*params.dis,cc.p(gui.Array_Pos_X[gui.curSelY],gui.Array_Pos_Y[gui.curSelX])), 
                    cc.DelayTime:create(0.1),
                    cc.CallFunc:create( function ()
                      cclog('CallFunc............')
                        if params.changeToNum then
                             cclog('changeToNum...')
                            sp:getChildByTag(123):setString(params.changeToNum)
                        end
                        if params.callback then
                            params.callback()
                        end
                    end)))
            else
                -- cclog('move down sp is nil')
            end
        end


        local function tryMoveDownForMerge()
            if gui.curSelX >= cfg.gh then do return false end end
            local canMerge = false
--            cclog('gui.curSelX:',gui.curSelX)
            for i=1,cfg.gw do
--                cclog('i:',i)
--                cclog('gameMap[gui.curSelX + 1][i]:',gameMap[gui.curSelX + 1][i])
--                cclog('gameMap[gui.curSelX ][i]:',gameMap[gui.curSelX ][i])
                if gameMap[gui.curSelX + 1][i] > 0 and gameMap[gui.curSelX][i] > 0 and gameMap[gui.curSelX + 1][i] == gameMap[gui.curSelX][i] then
                    canMerge = true
                    gui.curSelY = i
                    do break end
                end
            end
--            cclog('canMerge:',canMerge,'X:',gui.curSelX,'Y:',gui.curSelY)
            return canMerge
        end

        local function trySweepLine()
            for i=1, cfg.gw do
                if gameMap[gui.curSelX][i] <= 0 or gameMap[gui.curSelX][i] ~= gameMap[gui.curSelX][1] then
                    do return false end
                end
            end
            return true
        end

        local function moveOneDistance(i,j,callback)
            -- cclog('moveOneDistance i:',i,'j:',j)
            local sp = gameMapNode[i-1][j]
            -- cclog('sp:',sp)
            gameMapNode[i][j] = sp
            if sp then
                sp:runAction(cc.Sequence:create(cc.MoveTo:create(0.1,cc.p(gui.Array_Pos_X[j],gui.Array_Pos_Y[i])),
                    cc.CallFunc:create(function ( ... )
                        if callback then
                            callback()
                        end
                    end)))
            else
                if callback then
                    callback()
                end
            end
        end

        local function sweepLine(line,callback)
            for i=1,cfg.gw do    --erase cur line obj
                if gameMapNode[line][i] ~= nil then
                    gameMapNode[line][i]:removeFromParent()
                    gameMapNode[line][i] = nil
                end
            end
            local moveCount = (line - 1) * cfg.gw
            local curMoveCount = 0
            for i=line,2,-1 do  -- just move,not erase
                for j=1,cfg.gw do
                    gameMap[i][j] = gameMap[i-1][j]
                    moveOneDistance(i,j,function ( ... )
                        curMoveCount = curMoveCount + 1
                        if curMoveCount == moveCount then
                            for i=1,cfg.gw do    --set first line nil
                                gameMap[1][i] = 0
                                gameMapNode[1][i] = nil
                            end
                            if callback then
                                callback()
                            end
                        end
                    end)
                end
            end
        end
        local function tryMergeAndSweep()
--            cclog('---------------tryMergeAndSweep,x,y:',gui.curSelX,gui.curSelY)
            if trySweepLine() or tryMoveDownForMerge() then
                if trySweepLine() then
--                cclog('sweepline ..')
                    total_score = total_score + cfg.gw * gameMap[gui.curSelX][1]
                    -- cclog('----------> total_score :',total_score)
                    self:playEffect(clear_effect)
                    sweepLine(gui.curSelX,function ( ... )
                        gui:getChildByName('score'):setString(tostring(total_score))
                        if tryMoveDownForMerge() then
                            self:playEffect(merge_effect)
                            gui.moveDownForMerge()
                        else
                            showNewRandNumber()
                        end
                    end)
                elseif tryMoveDownForMerge() then
--                cclog('movedownformerge..')
                    self:playEffect(merge_effect)
                    gui.moveDownForMerge()
                else
--                cclog('111 show new Rand number')
                    showNewRandNumber()
                end
            else
--                cclog('22 show new Rand number')
                showNewRandNumber()
            end
        end
        local function moveDownForMerge( ... )
            -- cclog('#sweep move Next !!!!')
--            cclog('11 gui.curSelX:',gui.curSelX)
            gameMap[gui.curSelX + 1][gui.curSelY] = gameMap[gui.curSelX][gui.curSelY] * 2
            gameMap[gui.curSelX][gui.curSelY] = 0
            gui.curSelX = gui.curSelX + 1
--            cclog('12 gui.curSelX:',gui.curSelX)
            move{
                dis = 1,
                changeToNum = gameMap[gui.curSelX][gui.curSelY],
                moveNode = gameMapNode[gui.curSelX-1][gui.curSelY],
                callback = function ( ... )
--                    cclog('moveDownForMerge callback')
                    gameMapNode[gui.curSelX-1][gui.curSelY] = nil --擦除上层节点
                    gui.curSelX = gui.curSelX -1 --回退到上上层节点
--                    cclog('23 gui.curSelX:',gui.curSelX)
                    --当前合并列 向下滚动
                    local moveCount = gui.curSelX - 1
--                    cclog('moveCount:',moveCount)
                    local curMoveCount = 0

                    local function moveEnd( ... )
--                        cclog('moveOneDistance ended')
                        gameMap[1][gui.curSelY] = 0
                        gameMapNode[1][gui.curSelY] = nil
                        gui.curSelX = gui.curSelX + 1 --移动到下层 for seepline
                        -- cclog('24 gui.curSelX:',gui.curSelX)
                        tryMergeAndSweep()
                    end

                    if curMoveCount >= moveCount then
                        moveEnd()
                    end

                    for i = gui.curSelX,2,-1 do
                        gameMap[i][gui.curSelY] = gameMap[i-1][gui.curSelY]
                        moveOneDistance(i,gui.curSelY,function ( ... )
                            curMoveCount = curMoveCount + 1
--                            cclog('curMoveCount:',curMoveCount)
                            if curMoveCount >= moveCount then
                                moveEnd()
                            end
                        end)
                    end
                end,
            }
        end
        gui.moveDownForMerge = moveDownForMerge
        
        local dis = 0
        for i=2,cfg.gh do
            if gameMap[i][gui.curSelY] ~= nil then
                if gameMap[i][gui.curSelY] > 0 then
--                    cclog('gameMap[i][gui.curSelY]:',i,gui.curSelY,gameMap[i][gui.curSelY])
--                    cclog('x:',gui.curSelX)
                    gameMap[i - 1][gui.curSelY] = gameMap[gui.curSelX][gui.curSelY]
--                    cclog('value:',gameMap[gui.curSelX][gui.curSelY])
                    dis = i - 1 - gui.curSelX
                    gameMap[gui.curSelX][gui.curSelY] = (dis > 0) and 0 or gameMap[gui.curSelX][gui.curSelY]
                    gui.curSelX = i - 1
--                    cclog('xx:',gui.curSelX)
--                    cclog('xx value:',gameMap[gui.curSelX][gui.curSelY])
                    do break end
                elseif gameMap[i][gui.curSelY]  == 0 and i == cfg.gh then
                    gameMap[i][gui.curSelY] = gameMap[gui.curSelX][gui.curSelY]
                    dis = i - gui.curSelX
                    gameMap[gui.curSelX][gui.curSelY] = 0
                    gui.curSelX = i
                    do break end
                end
            end
        end
        
--        cclog('move dis:',dis)
--        cclog('gameMap[gui.curSelX][gui.curSelY]:',gameMap[gui.curSelX][gui.curSelY])
        if dis >= 0 then
            local layer = self:createNoTouchLayer()
            gui:addChild(layer,234,234)
            move{
                dis = dis,
                callback = function ( ... )
                    tryMergeAndSweep()
                end,
            }
        else
            showNewRandNumber()
        end
        
    end
end

function GameScene:playEffect(effect)
    if effect == nil or effect_map[effect] == nil then do return end end
    cc.SimpleAudioEngine:getInstance():playEffect(cfg[effect_map[effect]])
end

return GameScene
