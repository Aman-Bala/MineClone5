function mcl_enchanting.enchantments_snippet(_, _, itemstack)
	if not itemstack then
		return
	end
	local enchantments = mcl_enchanting.get_enchantments(itemstack)
	local text = ""
	for enchantment, level in pairs(enchantments) do
		text = text ..  mcl_enchanting.get_colorized_enchantment_description(enchantment, level) .. "\n"
	end
	if text ~= "" then
		return  text, false
	end
end

table.insert(tt.registered_snippets, 1, mcl_enchanting.enchantments_snippet) 
