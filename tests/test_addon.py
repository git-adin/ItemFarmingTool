"""Lua 5.1 integration tests for the actual addon files and UI callbacks."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.tools'))
# Permit the existing workspace's local test runtime without bundling it in releases.
sys.path.append(str(ROOT.parent / '.tools'))
from lupa.lua51 import LuaRuntime


class AddonTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute((ROOT / 'tests/wow_mock.lua').read_text())
        self.ns = self.lua.table()
        self.lua.globals().ns = self.ns
        for name in ['Core.lua', 'UI.lua']:
            self.lua.execute((ROOT / 'ItemFarmingTool' / name).read_text(), 'ItemFarmingTool', self.ns)
        self.check("Fire('ADDON_LOADED','ItemFarmingTool'); Fire('PLAYER_LOGIN')")

    def check(self, code):
        self.lua.execute(code)

    def test_multiple_items_bag_only_and_reagent_bag(self):
        self.check('''
            bags[0]={{itemID=2589,stackCount=12},{itemID=2589,stackCount=8}}
            bags[2]={{itemID=2770,stackCount=7}}
            bags[5]={{itemID=2770,stackCount=3}}
            bags[-1]={{itemID=2589,stackCount=999}}
            bags[6]={{itemID=2589,stackCount=999}}
            assert(ns.AddItem('2589',20)); assert(ns.AddItem('2770',15))
            assert(ns.counts[2589]==20 and ns.counts[2770]==10)
            assert(ns.frame:IsShown())
        ''')

    def test_inventory_events_decrease_and_batch(self):
        self.check('''
            bags[0]={{itemID=2589,stackCount=20}}
            ns.AddItem('2589',20)
            scans=0
            bags[0][1].stackCount=4
            Fire('BAG_UPDATE',0); Fire('BAG_UPDATE_DELAYED'); Fire('BAG_UPDATE',1)
            assert(#timers==1 and ns.counts[2589]==20)
            Tick(); assert(ns.counts[2589]==4 and scans==1)
            bags[0]={}; Fire('BAG_UPDATE_DELAYED'); Tick()
            assert(ns.counts[2589]==nil)
        ''')

    def test_legacy_bag_api(self):
        self.check('''
            C_Container=nil; Enum=nil
            GetContainerNumSlots=function(bag) return bag==0 and 2 or 0 end
            GetContainerItemInfo=function(bag,slot)
                if slot==1 then return 1,5,false,1,false,false,'|Hitem:2589|h[Linen]|h' end
                return 1,2,false,1,false,false,nil,false,false,2589
            end
            ns.AddItem('2589',10); assert(ns.counts[2589]==7)
        ''')

    def test_ids_links_names_and_duplicate_goals(self):
        self.check('''
            itemData[2589]={name='Linen Cloth',icon=123}
            assert(ns.AddItem('Linen Cloth',20))
            assert(ns.AddItem('|cffffffff|Hitem:2589:0|h[Linen Cloth]|h|r',30))
            assert(#ns.db.items==1 and ns.db.items[1].goal==30)
            assert(ns.AddItem(' item:2770 ',12)); assert(#ns.db.items==2)
            assert(not ns.AddItem('unknown name',5))
        ''')

    def test_invalid_input_does_not_mutate_goals(self):
        self.check('''
            for _,goal in ipairs({'',0,-1,1.5,'abc',1000000,math.huge,0/0}) do
                assert(not ns.AddItem('2589',goal))
            end
            for _,id in ipairs({'',0,-1,'1.5','not an item','2147483648'}) do
                assert(not ns.AddItem(tostring(id),5))
            end
            assert(not ns.AddItem(nil,5)); assert(#ns.db.items==0)
        ''')

    def test_uncached_item_data_is_refreshed(self):
        self.check('''
            ns.AddItem('2589',20); assert(requestedItem==2589)
            itemData[2589]={name='Linen Cloth',icon=123}
            Fire('GET_ITEM_INFO_RECEIVED',999); assert(#timers==0)
            Fire('GET_ITEM_INFO_RECEIVED',2589,true); Tick()
            local found=false
            for _,f in ipairs(frames) do if f.text=='Linen Cloth' then found=true end end
            assert(found)
        ''')

    def test_restore_saved_data_and_sanitize(self):
        self.check('''
            ns.db=nil
            ItemFarmingToolDB={items={{id=2589,goal=20},{id=2589,goal=50},false,
                {id=-1,goal=2},{id=2770,goal=0},{id='2770',goal='10'}},
                hidden=true,locked=true,collapsed=true,position={point='evil',x=0,y=0}}
            ns.LoadSettings()
            assert(#ns.db.items==2 and ns.db.items[1].goal==20)
            assert(ns.db.items[2].id==2770 and ns.db.position==nil)
            assert(ns.db.hidden and ns.db.locked and ns.db.collapsed)
        ''')

    def test_item_limit_allows_editing_existing_target(self):
        self.check('''
            for i=1,100 do assert(ns.AddItem(tostring(i),10)) end
            assert(not ns.AddItem('101',10))
            assert(ns.AddItem('1',50) and #ns.db.items==100)
            ns.RemoveItem(50); assert(ns.AddItem('101',10))
        ''')

    def test_commands_and_visibility(self):
        self.check('''
            assert(SLASH_ITEMFARMINGTOOL1=='/ift')
            ns.Command('add Linen Cloth 20'); assert(#ns.db.items==0)
            itemData[2589]={name='Linen Cloth'}
            ns.Command('add Linen Cloth 20'); assert(ns.Find(2589).goal==20)
            ns.Command('hide'); assert(not ns.frame:IsShown())
            ns.Command(''); assert(ns.frame:IsShown())
            ns.Command('lock'); assert(ns.db.locked)
            ns.Command('unlock'); assert(not ns.db.locked)
            ns.Command('remove 2589'); assert(#ns.db.items==0)
            ns.Command('help'); assert(#messages>=2)
        ''')

    def test_progress_labels_completion_and_regression(self):
        self.check('''
            bags[0]={{itemID=2589,stackCount=25}}; ns.AddItem('2589',20)
            local row
            for _,f in ipairs(frames) do if f.id==2589 and f.bar then row=f end end
            assert(row.bar.value==1 and row.count.text=='25+ / 20')
            assert(row.detail.text=='Goal reached')
            bags[0][1].stackCount=3; Fire('BAG_UPDATE_DELAYED'); Tick()
            assert(row.bar.value==0.15 and row.detail.text=='Up to 17 still needed')
        ''')

    def test_edit_goal_and_remove_pooled_rows(self):
        self.check('''
            ns.AddItem('2589',20); ns.AddItem('2770',10)
            local row
            for _,f in ipairs(frames) do if f.id==2589 and f.bar then row=f end end
            row.scripts.OnClick(row)
            assert(ns.editor:IsShown() and ns.goalInput:HasFocus())
            ns.goalInput:SetText('50'); ns.goalInput.scripts.OnEnterPressed(ns.goalInput)
            assert(ns.Find(2589).goal==50 and not ns.editor:IsShown())
            row.remove.scripts.OnClick(row.remove)
            assert(not ns.Find(2589) and row.id==2770)
            row.remove.scripts.OnClick(row.remove); assert(#ns.db.items==0)
        ''')

    def test_drag_item_and_shift_click(self):
        self.check('''
            cursor={'item',2589}; ns.frame.scripts.OnReceiveDrag(ns.frame)
            assert(cursor==nil and ns.itemInput:GetText()=='2589')
            ns.itemInput:SetFocus(); shifted=true
            hooks.HandleModifiedItemClick('|Hitem:2770|h[Copper Ore]|h')
            assert(ns.itemInput:GetText():find('2770'))
            ns.goalInput:SetText('30'); ns.goalInput.scripts.OnEnterPressed(ns.goalInput)
            assert(ns.Find(2770).goal==30)
        ''')

    def test_collapse_lock_position_and_reset(self):
        self.check('''
            local drag=ns.frame.scripts.OnDragStart
            ns.db.locked=true; drag(ns.frame); assert(not ns.frame.moving)
            ns.db.locked=false; drag(ns.frame); assert(ns.frame.moving)
            ns.frame:SetPoint('TOPLEFT',UIParent,'TOPLEFT',150,-100)
            ns.frame.scripts.OnDragStop(ns.frame)
            assert(ns.db.position.x==150 and ns.db.position.y==-100)
            ns.db.collapsed=true; ns.Render(); assert(ns.frame:GetHeight()==36)
            ns.Command('hide'); ns.Command('reset'); assert(ns.frame:IsShown() and ns.db.position==nil)
            ns.db.collapsed=false; ns.Render(); assert(ns.frame:GetHeight()>36)
        ''')

    def test_scrolling_and_removal_clamps_offset(self):
        self.check('''
            for i=1,12 do ns.AddItem(tostring(i),5) end
            local scroll
            for _,f in ipairs(frames) do if f.kind=='ScrollFrame' then scroll=f end end
            scroll.scripts.OnMouseWheel(scroll,-100)
            assert(scroll:GetVerticalScroll()==224)
            for i=1,6 do ns.RemoveItem(i) end
            assert(scroll:GetVerticalScroll()==0)
        ''')

    def test_hidden_tracker_updates_without_polling(self):
        self.check('''
            ns.AddItem('2589',20); ns.Command('hide')
            bags[0]={{itemID=2589,stackCount=9}}
            Fire('BAG_UPDATE_DELAYED'); Tick(); assert(ns.counts[2589]==9)
            ns.Command('show'); assert(ns.frame:IsShown())
            for _,f in ipairs(frames) do assert(not f.scripts.OnUpdate) end
        ''')

    def test_bank_totals_exclude_equipment_and_account_storage(self):
        self.check('''
            bags[0]={{itemID=2589,stackCount=10}}
            bankItems[2589]=25; equippedItems[2589]=2
            reagentBankItems[2589]=5; accountBankItems[2589]=999
            ns.AddItem('2589',40)
            assert(ns.db.bankCounts[2589]==nil)
            Fire('BANKFRAME_OPENED'); Tick()
            assert(ns.db.bankCounts[2589]==30 and ns.counts[2589]==10)
            local row
            for _,f in ipairs(frames) do if f.id==2589 and f.bar then row=f end end
            assert(row.count.text=='40 / 40' and row.detail.text=='Goal reached')
            assert(row.storage.text=='Bags 10  |  Bank 30')
            assert(ns.db.bankUpdatedAt==time())
        ''')

    def test_bank_deposits_and_withdrawals_survive_immediate_close(self):
        self.check('''
            bags[0]={{itemID=2589,stackCount=10}}; bankItems[2589]=20
            ns.AddItem('2589',30); Fire('BANKFRAME_OPENED'); Tick()
            bags[0][1].stackCount=5; bankItems[2589]=25
            Fire('PLAYERBANKSLOTS_CHANGED',1)
            Fire('BANKFRAME_CLOSED'); bankItems[2589]=0; Tick()
            assert(ns.counts[2589]==5 and ns.db.bankCounts[2589]==25)
            bankItems[2589]=25; Fire('BANKFRAME_OPENED'); Tick()
            bags[0][1].stackCount=15; bankItems[2589]=15
            Fire('BAG_UPDATE',0); Fire('BANKFRAME_CLOSED'); Tick()
            assert(ns.counts[2589]+ns.db.bankCounts[2589]==30)
        ''')

    def test_bank_cache_persists_and_closed_bank_is_not_queried(self):
        self.check('''
            ns.AddItem('2589',40); bankItems[2589]=30
            Fire('BANKFRAME_OPENED'); Tick(); Fire('BANKFRAME_CLOSED'); Tick()
            ns.db=nil; ns.LoadSettings()
            assert(ns.db.bankCounts[2589]==30 and ns.db.bankUpdatedAt==time())
            C_Item.GetItemCount=function() error('Closed bank must not be queried') end
            bags[0]={{itemID=2589,stackCount=4}}
            Fire('BAG_UPDATE_DELAYED'); Tick()
            assert(ns.counts[2589]==4 and ns.db.bankCounts[2589]==30)
            ns.AddItem('2770',10); assert(ns.db.bankCounts[2770]==nil)
        ''')

    def test_new_item_at_bank_and_empty_bank_refresh(self):
        self.check('''
            Fire('BANKFRAME_OPENED'); Tick()
            bankItems[2589]=12; ns.AddItem('2589',15)
            assert(ns.db.bankCounts[2589]==12)
            bankItems[2589]=nil; Fire('PLAYERBANKSLOTS_CHANGED',1); Tick()
            assert(ns.db.bankCounts[2589]==0)
            ns.RemoveItem(2589); assert(ns.db.bankCounts[2589]==nil)
        ''')

    def test_failed_bank_scan_is_unknown_and_legacy_count_supported(self):
        self.check('''
            ns.AddItem('2589',20); Fire('BANKFRAME_OPENED'); Tick()
            assert(ns.db.bankCounts[2589]==0)
            C_Item.GetItemCount=function() error('Unavailable') end
            Fire('PLAYERBANKSLOTS_CHANGED',1); Tick()
            assert(ns.db.bankCounts[2589]==nil)
            GetItemCount=function(id, bank) return bank and 13 or 3 end
            C_Item.GetItemCount=nil
            Fire('PLAYERBANKSLOTS_CHANGED',1); Tick()
            assert(ns.db.bankCounts[2589]==10)
            Fire('PLAYER_ENTERING_WORLD'); Tick(); assert(not ns.bankOpen)
        ''')

    def test_corrupt_bank_cache_is_sanitized(self):
        self.check('''
            ns.db=nil
            ItemFarmingToolDB={items={{id=2589,goal=20},{id=2770,goal=10}},
                bankCounts={[2589]=-1,[2770]=0,[999]=100},bankUpdatedAt=math.huge}
            ns.LoadSettings()
            assert(ns.db.bankCounts[2589]==nil and ns.db.bankCounts[2770]==0)
            assert(ns.db.bankCounts[999]==nil and ns.db.bankUpdatedAt==nil)
        ''')


if __name__ == '__main__':
    unittest.main()
