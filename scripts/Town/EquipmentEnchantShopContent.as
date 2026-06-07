class EquipmentEnchantShopContent : AShopContent
{
	Equipment::Item@ m_currEnchanting;
	int m_currEnchantingSlot;

	bool IsAllowedArmorSlot(Equipment::Slot slot)
	{
		return slot == Equipment::Slot::Head
			|| slot == Equipment::Slot::Chest
			|| slot == Equipment::Slot::Feet
			|| slot == Equipment::Slot::Hands
			|| slot == Equipment::Slot::Back;
	}

	bool CanUseEpicEnchant(Equipment::Item@ item)
	{
		return item !is null && IsAllowedArmorSlot(item.GetSlot());
	}


	EquipmentEnchantShopContent() {}
	EquipmentEnchantShopContent(UnitPtr u, SValue& params) { super(u, params); }

	string GetName() override { return ".npc.shop.equipment_enchant"; }

	void Open(PlayerRecord@ player, int level) override
	{
		AShopContent::Open(player, level);
		@m_currEnchanting = null;
		m_currEnchantingSlot = -1;
	}

	Item::Quality GetEnchantQualityBySlot(int slot)
	{
		if (slot == 0)
			return Item::Quality::Common;
		if (slot == 1)
			return Item::Quality::Rare;
		if (slot == 2)
			return Item::Quality::Epic;
		return Item::Quality::None;
	}

	array<IShopItem@> GetItems() override
	{
		array<IShopItem@> ret;
		
		if (m_currEnchanting !is null)
		{
			auto@ blueprints = g_myTownRecord.m_blueprints;
			
			array<Equipment::ItemModifier@> noMods;
			Equipment::Generator eqGen;
			auto qual = GetEnchantQualityBySlot(m_currEnchantingSlot);
			auto itemMods = eqGen.GetAllPossibleItemModifiers(m_currEnchanting.baseItem, qual, m_currEnchanting.GetItemLevel(true), noMods);
			
			for (uint i = 0; i < itemMods.length(); i++)
			{
				auto itemMode = itemMods[i].itemMod;
				if (itemMode.m_blueprintHash != 0 && !blueprints.HasBlueprint(itemMode.m_blueprintHash))
					continue;
				
				ret.insertLast(EquipmentEnchantSetModShopContentItem(this, m_currEnchanting, itemMode));
			}
		}
		else
		{
			for (uint i = 0; i < m_player.equipped.m_items.length(); i++)
			{
				auto item = m_player.equipped.m_items[i];
				if (item is null)
					continue;
				auto eqItem = cast<Equipment::Item>(item);
				if (eqItem is null)
					continue;
				ret.insertLast(EquipmentEnchantShopContentItem(this, eqItem, i));
			}
		}
		
		return ret;
	}

	AWindowObject@ MakeShopWindow(GUIBuilder@ guiBuilder) override
	{
		@m_window = EnchantEquipmentWindow(guiBuilder, this);
		return m_window; 
	}
}

class EquipmentEnchantShopContentItem : IShopItem
{
	EquipmentEnchantShopContent@ m_shop;
	Equipment::Item@ m_item;
	uint m_index;

	EquipmentEnchantShopContentItem(EquipmentEnchantShopContent@ shop, Equipment::Item@ item, uint index)
	{
		@m_shop = shop;
		@m_item = item;
		m_index = index;
	}

	string GetID() { return m_index; }
	uint GetIDHash() { return m_index; }
	string GetTitle() { return "\\c" + Item::QualityColorString(m_item.GetQuality()) + m_item.GetName(); }
	string GetSubTitle() { return "enchant"; }
	string GetDescription() { return ""; }
	ScriptSprite@ GetIcon() { return m_item.GetIcon(); }
	Sprite@ GetBackground() { return GetQualitySprite(m_item.GetQuality()); }
	ShopCost@ GetCost() { return null; }
	bool AutoSpendCost() { return true; }
	string OnFunc() { return "pick"; }
	bool IsAvailable(PlayerRecord@ player) { return true; }
	void ShowTooltip(WindowManager@ manager, bool compare) {}
	Item::Item@ GetItem() { return m_item; }
}

class EquipmentEnchantSetModShopContentItem : IShopItem
{
	EquipmentEnchantShopContent@ m_shop;
	Equipment::Item@ m_item;
	Equipment::ItemModifier@ m_mod;

	EquipmentEnchantSetModShopContentItem(EquipmentEnchantShopContent@ shop, Equipment::Item@ item, Equipment::ItemModifier@ mod)
	{
		@m_shop = shop;
		@m_item = item;
		@m_mod = mod;
	}

	string GetID() { return m_mod.m_id; }
	uint GetIDHash() { return 0; }
	string GetTitle() { return (m_mod.prefixName.isEmpty() ? m_mod.suffixName : m_mod.prefixName); }
	string GetSubTitle() { return "set modifier"; }
	string GetDescription() { return ""; }
	ScriptSprite@ GetIcon() { return null; }
	Sprite@ GetBackground() { return GetQualitySprite(m_mod.quality); }
	ShopCost@ GetCost() { return null; }
	bool AutoSpendCost() { return true; }
	string OnFunc() { return "setmod"; }
	bool IsAvailable(PlayerRecord@ player) { return true; }
	Item::Item@ GetItem() { return null; }
	
	void ShowTooltip(WindowManager@ manager, bool compare) 
	{
		if (m_shop is null || m_shop.m_currEnchanting is null)
			return;
		
		auto currItem = cast<Equipment::Item>(m_shop.m_currEnchanting.Copy());
		int idx = GetCurrEncSlotIdx(m_shop, m_shop.m_currEnchantingSlot);
		if (idx < 0)
			return;
		@currItem.mods[idx] = m_mod;
		currItem.Finalize(currItem.intensity, int(currItem.itemLevel), int(currItem.upgradeLevel), currItem.colorA, currItem.colorB);
		
		ITooltip@ tt = null;
		if (compare)
			@tt = Item::BuildCompareItemTooltip(currItem, currItem.GetPrice());
		else
			@tt = Item::BuildItemTooltip(currItem, currItem.GetPrice(), 1, false);
		
		manager.SetTooltip(tt, true);
	}
}


int GetCurrEncSlotIdx(EquipmentEnchantShopContent shop, int slot)
{
	if (shop.m_currEnchanting is null)
		return -1;
	
	Item::Quality qual = shop.GetEnchantQualityBySlot(slot);
	for (uint i = 0; i < shop.m_currEnchanting.mods.length(); i++)
	{
		if (shop.m_currEnchanting.mods[i].quality == qual)
			return i;
	}
	
	if (slot == 1)
	{
		bool foundFirst = false;
		for (uint i = 0; i < shop.m_currEnchanting.mods.length(); i++)
		{
			if (shop.m_currEnchanting.mods[i].quality == Item::Quality::Common)
			{
				if (foundFirst)
					return i;
				foundFirst = true;
			}
		}
	}
	else if (slot == 2)
	{
		for (uint i = 0; i < shop.m_currEnchanting.mods.length(); i++)
		{
			if (shop.m_currEnchanting.mods[i].quality == Item::Quality::Rare)
				return i;
		}
	}
	
	return -1;
}


class EnchantEquipmentWindow : ShopWindow
{
	Widget@ m_entryTemplate;
	string uncommonColStr = "\\c" + Item::QualityColorString(Item::Quality::Uncommon);
	string rareColStr = "\\c" + Item::QualityColorString(Item::Quality::Rare);
	string epicColStr = "\\c" + Item::QualityColorString(Item::Quality::Epic);

	EnchantEquipmentWindow(GUIBuilder@ b, AShopContent@ content)
	{
		super(b, content, "gui/shops/enchanter_equipment.gui");
		
		@m_entryTemplate = m_widget.GetWidgetById("entry-template");
		Refresh();
	}

	string MakeQualityNameString(Item::Quality quality)
	{
		return "\\c" + Item::QualityColorString(quality) + Resources::GetString(".item.quality." + Item::QualityToString(quality)) + "\\d";
	}

	ShopCost@ GetQualityUpgradeCost(Equipment::Item@ equipment)
	{
		int baseCost = 1 + int(pow(equipment.GetItemLevel(true), 1.0f - m_shopContent.m_shopLevel * 0.05f) * 0.5f);
		if (equipment.GetQuality() == Item::Quality::Common)
			return ShopCost(MaterialType::Crystals, int(baseCost * 2.5f));
		else if (equipment.GetQuality() == Item::Quality::Uncommon)
			return ShopCost(MaterialType::Dust, baseCost);
		else if (equipment.GetQuality() == Item::Quality::Rare)
			return ShopCost(MaterialType::Dust, baseCost * 4);
		return null;
	}

	ShopCost@ GetEquipmentModCost(Equipment::Item@ equipment, Item::Quality modQuality)
	{
		int baseCost = 2 + int(pow(equipment.GetItemLevel(true), 1.3f - m_shopContent.m_shopLevel * 0.1f) * 0.25f);
		if (modQuality == Item::Quality::Common)
			return ShopCost(MaterialType::Crystals, int(baseCost * 2.5f));
		if (modQuality == Item::Quality::Epic)
			return ShopCost(MaterialType::Dust, max(1, int(float(baseCost) * 3.0f + 0.5f)));
		return ShopCost(MaterialType::Dust, baseCost);
	}

	void SetUpgradeButton(int i, IShopItem@ shopItem, EnchantEquipmentItem@ entry, Widget@ button)
	{
		auto entryOption = cast<EntryShopEnchantEquipmentItemOption>(button);
		auto getEquip = cast<Equipment::Item>(shopItem.GetItem());
		ShopCost@ cost = GetQualityUpgradeCost(getEquip);
		
		string newQual = "";
		if (getEquip.GetQuality() == Item::Quality::Common)
			newQual = MakeQualityNameString(Item::Quality::Uncommon);
		else if (getEquip.GetQuality() == Item::Quality::Uncommon)
			newQual = MakeQualityNameString(Item::Quality::Rare);
		else
			newQual = MakeQualityNameString(Item::Quality::Epic);
		
		entryOption.m_visible = true;
		entryOption.SetTitle(Resources::GetString(".menu.enchanter.upgrade", {{"quality", newQual}}));
		entryOption.SetCostText(cost.GetText(m_shopContent.m_player, true));
		entryOption.m_funcConfirm = "upgrade";
		entryOption.m_navPos.y = i;
		@entryOption.m_shopItem = shopItem;
	}

	void SetEnchantButton(int i, IShopItem@ shopItem, EnchantEquipmentItem@ entry, Widget@ button)
	{
		auto entryOption = cast<EntryShopEnchantEquipmentItemOption>(button);
		entryOption.m_visible = true;
		entryOption.SetTitle(Resources::GetString(".menu.enchanter.enchant"));
		entryOption.SetCostText("");
		entryOption.m_funcConfirm = "enchant";
		entryOption.m_navPos.y = i;
		@entryOption.m_shopItem = shopItem;
	}

	string GetEnchantName(Equipment::ItemModifier@ mod, int slot)
	{
		if (mod is null)
			return "?";
		if (slot == 0)
			return uncommonColStr + (mod.prefixName.isEmpty() ? mod.suffixName : mod.prefixName);
		if (slot == 1)
			return rareColStr + (mod.suffixName.isEmpty() ? mod.prefixName : mod.suffixName);
		if (slot == 2)
			return epicColStr + (mod.suffixName.isEmpty() ? mod.prefixName : mod.suffixName);
		return "?";
	}

	string GetSlotColorByIndex(int slot)
	{
		if (slot == 0) return uncommonColStr;
		if (slot == 1) return rareColStr;
		if (slot == 2) return epicColStr;
		return uncommonColStr;
	}

	void Refresh() override
	{
		if (m_entryTemplate is null)
			return;
		
		m_shopItems = m_shopContent.GetItems();
		auto shop = cast<EquipmentEnchantShopContent>(m_shopContent);
		if (shop.m_currEnchanting is null)
		{
			@m_itemList = cast<ScrollbarWidget>(m_widget.GetWidgetById("equipment-list"));
			m_itemList.m_enabled = true;
			m_itemList.ClearChildren();
			
			m_widget.GetWidgetById("equipment").m_visible = true;
			m_widget.GetWidgetById("enchant").m_visible = false;
			
			for (uint i = 0; i < m_shopItems.length(); i++)
			{
				auto currItem = cast<IShopItem>(m_shopItems[i]);
				auto getEquip = currItem.GetItem();
				
				bool canEnchant = m_shopContent.m_shopLevel > 0;
				bool canUpgrade = false;
				if (getEquip.GetQuality() == Item::Quality::Common)
				{
					canUpgrade = true;
					canEnchant = false;
				}
				if (getEquip.GetQuality() == Item::Quality::Uncommon || getEquip.GetQuality() == Item::Quality::Rare)
					canUpgrade = true;
				
				int numFeats = 0;
				if (canEnchant) numFeats++;
				if (canUpgrade) numFeats++;
				if (numFeats == 0) continue;
				
				auto entry = cast<EnchantEquipmentItem>(m_entryTemplate.Clone());
				entry.SetID(currItem.GetID());
				entry.m_visible = true;
				if (numFeats == 1)
					entry.m_titleTextWidth += 40;
				
				entry.SetTitle(currItem.GetTitle());
				entry.SetIcon(currItem.GetIcon());
				@entry.m_shopItem = currItem;
				
				if (canEnchant)
				{
					SetEnchantButton(i, currItem, entry, entry.GetWidgetById("button-1"));
					if (canUpgrade)
						SetUpgradeButton(i, currItem, entry, entry.GetWidgetById("button-2"));
				}
				else
					SetUpgradeButton(i, currItem, entry, entry.GetWidgetById("button-1"));
				
				m_itemList.AddChild(entry);
			}
			
			if (m_itemList.m_children.length() > 0)
				m_emptyPrompt.SetText("");
			else
				m_emptyPrompt.SetText(Resources::GetString(".menu.enchanter.no_equipment"));
		}
		else
		{
			@m_itemList = cast<ScrollbarWidget>(m_widget.GetWidgetById("enchant-list"));
			m_itemList.m_enabled = true;
			m_itemList.ClearChildren();
			
			m_widget.GetWidgetById("equipment").m_visible = false;
			m_widget.GetWidgetById("enchant").m_visible = true;
			
			auto currQual = shop.m_currEnchanting.GetQuality();
			auto mod1btn = m_widget.GetWidgetById("modifier-1");
			auto mod2btn = m_widget.GetWidgetById("modifier-2");
			auto mod3btn = m_widget.GetWidgetById("modifier-3");
			
			mod1btn.m_visible = int(currQual) >= int(Item::Quality::Uncommon);
			mod2btn.m_visible = int(currQual) >= int(Item::Quality::Rare);
			
			bool canUseEpicSlot = shop.CanUseEpicEnchant(shop.m_currEnchanting);
			if (mod3btn !is null)
				mod3btn.m_visible = int(currQual) >= int(Item::Quality::Epic) && canUseEpicSlot;
			
			mod1btn.GetWidgetById("selected").m_visible = shop.m_currEnchantingSlot == 0;
			mod2btn.GetWidgetById("selected").m_visible = shop.m_currEnchantingSlot == 1;
			if (mod3btn !is null)
				mod3btn.GetWidgetById("selected").m_visible = shop.m_currEnchantingSlot == 2;
			
			int mod1idx = GetCurrEncSlotIdx(shop, 0);
			int mod2idx = GetCurrEncSlotIdx(shop, 1);
			int mod3idx = GetCurrEncSlotIdx(shop, 2);
			
			if (mod1btn.m_visible && mod1idx >= 0)
				cast<TextWidget>(mod1btn.GetWidgetById("text")).SetText(GetEnchantName(shop.m_currEnchanting.mods[mod1idx], 0));
			if (mod2btn.m_visible && mod2idx >= 0)
				cast<TextWidget>(mod2btn.GetWidgetById("text")).SetText(GetEnchantName(shop.m_currEnchanting.mods[mod2idx], 1));
			if (mod3btn !is null && mod3btn.m_visible && mod3idx >= 0)
				cast<TextWidget>(mod3btn.GetWidgetById("text")).SetText(GetEnchantName(shop.m_currEnchanting.mods[mod3idx], 2));
			
			string useStr = GetSlotColorByIndex(shop.m_currEnchantingSlot);
			auto template = m_widget.GetWidgetById("enchant-template");
			auto cost = GetEquipmentModCost(shop.m_currEnchanting, shop.GetEnchantQualityBySlot(shop.m_currEnchantingSlot));
			int currSlotIdx = GetCurrEncSlotIdx(shop, shop.m_currEnchantingSlot);
			
			for (uint i = 0; i < m_shopItems.length(); i++)
			{
				auto currItem = cast<EquipmentEnchantSetModShopContentItem>(m_shopItems[i]);
				auto entry = cast<ScalableSpriteRectButtonWidget>(template.Clone());
				entry.SetID(currItem.GetID());
				entry.m_visible = true;
				entry.m_navPos = ivec2(i % 2, 1 + i / 2);
				
				auto textW = cast<TextWidget>(entry.GetWidgetById("text"));
				auto costW = cast<TextWidget>(entry.GetWidgetById("cost"));
				textW.SetText(useStr + currItem.GetTitle());
				
				auto selectedW = entry.GetWidgetById("selected");
				if (currSlotIdx >= 0 && shop.m_currEnchanting.mods[currSlotIdx] is currItem.m_mod)
				{
					selectedW.m_visible = true;
					costW.SetText("");
				}
				else
				{
					selectedW.m_visible = false;
					costW.SetText(cost is null ? "" : cost.GetText(shop.m_player, true));
				}
				
				m_itemList.AddChild(entry);
			}
			
			auto emptyPrompt = cast<TextWidget>(m_widget.GetWidgetById("enchant-empty"));
			if (m_itemList.m_children.length() > 0)
				emptyPrompt.SetText("");
			else
				emptyPrompt.SetText(Resources::GetString(".menu.enchanter.no_modifiers"));
		}
		
		if (m_currencyText !is null)
		{
			auto record = GetLocalPlayerRecord();
			StringBuilder sb;
			
			sb += Resources::GetString(".tab.overlay.player.crys", {{ "amount", record.GetMaterial(MaterialType::Crystals) }});
			sb += " ";
			sb += Resources::GetString(".tab.overlay.player.dust", {{ "amount", record.GetMaterial(MaterialType::Dust) }});
			m_currencyText.SetText(sb.String());
		}
		
		MakeNavTexts();
	}

	void MakeNavTexts()
	{
		if (m_navigationBar is null)
			return;
		
		auto currInteractable = m_input.GetCurrentInteractable();
		if (currInteractable is null)
			return;
		
		array<string>@ rawTexts = currInteractable.NavigationBarText();
		array<KeyNavigationText@> navTexts;
		for (uint i = 0; i < rawTexts.length(); i++)
			navTexts.insertLast(KeyNavigationText(m_navigationBar.m_font.BuildText(rawTexts[i])));
		
		navTexts.insertLast(KeyNavigationText(m_navigationBar.m_font.BuildText(FormatKeyName(GetActionBinding("MenuContext")) + " " + Resources::GetString(".menu.nav.compare")), WindowInput::OnFunc(this.MenuContext)));
		m_navigationBar.BuildBar(navTexts, this);
	}

	void RefreshKeybinds(ControlMap@ currMap) override
	{
		MakeNavTexts();
	}

	void OnInteractableIndexChanged() override
	{
		MakeNavTexts();
		if (m_itemList is null)
			return;
		m_manager.CloseTooltip();
		if (m_closeButton !is null && m_input.m_mouseOnlyHovering is m_closeButton)
			return;

		int refIndex = m_itemList.m_children.findByRef(m_itemList.m_input.GetCurrentInteractable());
		if (refIndex == -1)
			return;
		auto shopItem = m_shopItems[refIndex];
		if (shopItem !is null)
			shopItem.ShowTooltip(m_manager, false);
	}

	void MenuContext() override
	{
		if (!m_shopContent.ShowInfo())
			return;
		int refIndex = m_itemList.m_children.findByRef(m_itemList.m_input.GetCurrentInteractable());
		if (refIndex == -1)
			return;
		auto shopItem = m_shopItems[refIndex];
		if (shopItem !is null)
			shopItem.ShowTooltip(m_manager, true);
	}

	void OnFunc(Widget@ sender, const string &in name) override
	{
		ShopWindow::OnFunc(sender, name);
		
		if (name == "upgrade")
		{
			auto entryOption = cast<EntryShopEnchantEquipmentItemOption>(sender);
			if (entryOption is null || entryOption.m_shopItem is null)
				return;
			
			auto getEquip = cast<Equipment::Item>(entryOption.m_shopItem.GetItem());
			if (getEquip is null)
				return;
			
			ShopCost@ cost = GetQualityUpgradeCost(getEquip);
			if (cost is null || !cost.CanAfford(m_shopContent.m_player))
				return;
			
			Equipment::Generator eqGen;
			auto qual = getEquip.GetQuality();
			if (qual == Item::Quality::Common)
				eqGen.m_qualities = Item::Quality::Uncommon;
			else if (qual == Item::Quality::Uncommon)
				eqGen.m_qualities = Item::Quality::Rare;
			else if (qual == Item::Quality::Rare)
				eqGen.m_qualities = Item::Quality::Epic;
			else
				return;
			
			cost.Spend(m_shopContent.m_player);
			eqGen.ModifyItem(getEquip);
			Refresh();
			RefreshInteractableWidgets(m_widget);
			m_shopContent.m_player.RefreshModifiers();
		}
		else if (name == "enchant")
		{
			auto entryOption = cast<EntryShopEnchantEquipmentItemOption>(sender);
			if (entryOption is null || entryOption.m_shopItem is null)
				return;
			
			auto shop = cast<EquipmentEnchantShopContent>(m_shopContent);
			@shop.m_currEnchanting = cast<Equipment::Item>(entryOption.m_shopItem.GetItem());
			shop.m_currEnchantingSlot = 0;
			Refresh();
			RefreshInteractableWidgets(m_widget);
		}
		else if (name == "modifier-1")
		{
			auto shop = cast<EquipmentEnchantShopContent>(m_shopContent);
			shop.m_currEnchantingSlot = 0;
			Refresh();
		}
		else if (name == "modifier-2")
		{
			auto shop = cast<EquipmentEnchantShopContent>(m_shopContent);
			shop.m_currEnchantingSlot = 1;
			Refresh();
		}
		else if (name == "modifier-3")
		{
			auto shop = cast<EquipmentEnchantShopContent>(m_shopContent);
			if (!shop.CanUseEpicEnchant(shop.m_currEnchanting))
				return;
			shop.m_currEnchantingSlot = 2;
			Refresh();
		}
		else if (name == "modify")
		{
			auto shop = cast<EquipmentEnchantShopContent>(m_shopContent);
			auto mod = Equipment::ItemModifier::Get(sender.m_id);
			
			auto cost = GetEquipmentModCost(shop.m_currEnchanting, shop.GetEnchantQualityBySlot(shop.m_currEnchantingSlot));
			if (cost is null || !cost.CanAfford(m_shopContent.m_player))
				return;
			
			auto currItem = shop.m_currEnchanting;
			int idx = GetCurrEncSlotIdx(shop, shop.m_currEnchantingSlot);
			if (idx < 0)
				return;
			if (currItem.mods[idx] is mod)
				return;
			
			@currItem.mods[idx] = mod;
			currItem.Finalize(currItem.intensity, int(currItem.itemLevel), int(currItem.upgradeLevel), currItem.colorA, currItem.colorB);
			cost.Spend(m_shopContent.m_player);
			
			Refresh();
			m_shopContent.m_player.RefreshModifiers();
		}
		else if (name == "close")
		{
			m_manager.CloseTooltip();
			m_closing = true;
		}
	}
}
