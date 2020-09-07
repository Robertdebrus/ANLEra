translation: ANL

ANL:
	wmlxgettext --recursive --directory=.. --domain=wesnoth-ANLEra -o wesnoth-ANLEra.pot
	# WORKAROUND, wmlxgettext does not detect these two:
	echo '' >> wesnoth-ANLEra.pot
	echo '#. [lua]: anl.build_recruit_options' >> wesnoth-ANLEra.pot
	echo '#. Text for the option to cancel. Decide later which unit to choose.' >> wesnoth-ANLEra.pot
	echo '#: ANLEra/utils/research.lua:202' >> wesnoth-ANLEra.pot
	echo 'msgid "Choose later."' >> wesnoth-ANLEra.pot
	echo 'msgstr ""' >> wesnoth-ANLEra.pot
	echo '' >> wesnoth-ANLEra.pot
	echo '#. [lua]: anl.build_recruit_options' >> wesnoth-ANLEra.pot
	echo '#. Text for the option to cancel. Just one unit is left to be chosen.' >> wesnoth-ANLEra.pot
	echo '#: ANLEra/utils/research.lua:205' >> wesnoth-ANLEra.pot
	echo 'msgid "No, maybe not."' >> wesnoth-ANLEra.pot
	echo 'msgstr ""' >> wesnoth-ANLEra.pot
	echo '' >> wesnoth-ANLEra.pot
	msgmerge -U de/LC_MESSAGES/wesnoth-ANLEra.po wesnoth-ANLEra.pot
	msgfmt -o de/LC_MESSAGES/wesnoth-ANLEra.mo de/LC_MESSAGES/wesnoth-ANLEra.po
