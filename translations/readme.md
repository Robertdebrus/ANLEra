Translations templates can be generated with:  
`wmlxgettext --domain=wesnoth-ANLEra -o translations/wesnoth-ANLEra.pot --recursive` 

pot and po files are essentially the same, just change the file extension to .po.  
An po-editor, such as _poedit_, is needed to translate them.  
When saving, the po-editor creates a .mo file - the machine readable version.  
It belongs to the location _translations/XY/LC_MESSAGES/wesnoth-ANLEra.mo_  
From version 1.13 on Wesnoth does as well accept .po files at this loation.

To update an already existing translation after string changes in the add-on, one needs to merge the po and pot file:
`msgmerge -U translation.po template.pot` (this will update the po file, make an backup before)

If you only have the .mo file and need a .po file, you can recover it:  
`msgunfmt wesnoth-ANLEra.mo -o wesnoth-ANLEra.po`

The [Era of Myths](https://github.com/sevu/EoM/tree/master/translations) contains more information about translations.
