<div align="center">

# ParcelMaker (Community Edition) User Manual

</div>

Version 5.0.0

Toshiba Corporation

## Table of contents

1. Introduction... 3

2. System requirements... 3

3. Installation & Setup... 4

3.1. Excel Setup... 4

3.2. Installation... 5

3.3. License file... 6

3.4. How to register ParcelMaker as an add-in of MS Excel ... 7

4. Parcel Workbook Creation ... 8

5. Manipulating sheets in a workbook ... 10

   5.1. How to add a new dictionary ... 10

   5.3. How to delete a dictionary ... 10

6. Parcel sheet... 11

   6.1. Overview ... 11

   6.2. Comment ... 12

   6.3. View control ... 12

7. Identifier for an ontological element ... 13

8. Editing cell column values ... 14

   8.1. Real-time validation ... 14

   8.2. Special GUIs for meta-properties ... 15

   8.2.1. General ... 15

   8.2.2. Synonymous name (MDC_P004_2) ... 16

   8.2.3. Superclass (MDC_P010) ... 17

   8.2.4. Is case of (MDC_P013) ... 18

   8.2.5. Applicable properties, types and documents (MDC_P014, MDC_P015 and MDC_P094) ... 19

   8.2.6. Imported properties, types and documents (MDC_P090, MDC_P091 and MDC_P093) ... 20

   8.2.7. Definition class (MDC_P021) ... 21

   8.2.8. Data type (MDC_P022) ... 22

   8.2.9. Unit in SGML (MDC_P023_2) ... 23

   8.2.10. Value format (MDC_P024) ... 24

   8.2.11. Condition (MDC_P028) ... 25

   8.2.12. DET classification (MDC_P040) ... 26

   8.2.13. Code for unit, Codes for alternative units and Quantity (MDC_P041,

MDC_P042 and MDC_P114) ... 27

8.2.14. Enumerated list of terms (MDC_P043) ... 28

8.2.15. Domain of the relation/function (MDC_P201 and MDC_P202) ... 29

8.2.16. ENUM_TYPE property ... 30

9. Viewer ... 32

9.1. Class viewer ... 32

9.2. Relation viewer ... 36

10. Instance data generation ... 37

11. Data exchange ... 40

11.1. Export ... 40

11.1.1. Exporting the active worksheet into another file ... 40

11.1.2. Exporting a dictionary into separate files ... 40

11.2. Import ... 40

11.2.1. Importing data from files into the active sheet ... 40

11.2.2. Importing data from another sheet into the active sheet ... 41

12. Set up ... 43

12.1. Setting the visibility of an item in a header section ... 43

12.2. Enable/disable ParcelMaker functions ... 44

12.3. How to change a language for displaying data ... 45

12.4. How to specify languages to be translated ... 45

12.5. How to set up a system environment ... 46

13. Error log ... 47

14. COPYRIGHT AND LICENSE AGREEMENT ... 50

## 1. Introduction

ParcelMaker $ ^{\mathrm{T M}} $ is an add-in software for Microsoft $ ^{(*1)} $ Excel $ ^{(*1)} $ , which helps editing both data dictionaries and their value instances based on the standardized spreadsheet interface as IEC 62656-1.

The typical features of ParcelMaker $ ^{TM} $ are as follows:

- Intuitive graphical interface for viewing and editing information about dictionaries and their value instances,

Real-time validation for a value in a cell column,

Data exchange with CSV data and a Microsoft Excel workbook file, and

Multilingual support.

## 2. System Requirements

ParcelMaker Community Edition requires the following environment.

<table border="1"><tr><td rowspan="3">Operating system</td><td>Microsoft Windows 7$ ^{(*1)}$</td></tr><tr><td>Microsoft Windows 8.1$ ^{(*1)}$</td></tr><tr><td>Microsoft Windows 10$ ^{(*1)}$</td></tr><tr><td rowspan="4">Microsoft Excel$ ^{(*1)}$</td><td>Microsoft Excel$ ^{(*1)}$ 2007</td></tr><tr><td>Microsoft Excel$ ^{(*1)}$ 2010 (32bit/64bit)</td></tr><tr><td>Microsoft Excel$ ^{(*1)}$ 2013 (32bit/64bit)</td></tr><tr><td>Microsoft Excel$ ^{(*1)}$ 2016 (32bit/64bit)</td></tr></table>

## 3. Installation & Setup

## 3.1. Excel Setup

Setup the edit option of Excel as follows:

A press the [Office Button] and select [Excel Options] on the bottom

B select [Advanced] from the menu items on the left, and

C uncheck the checkbox of "Extend data range formats and formulas" in the middle of the Advanced] options (Figure 1).

![](page=4,bbox=[417, 815, 1568, 1638])

<div align="center">

Figure 1: Setting of the "Advanced" options

</div>

## 3.2. Installation

Run the installer of ParcelMaker and click on the Next button on every screen, and then click on the Finish button to finish installation. The add-in program and several configuration files are automatically copied into the following default installation path.

## C:¥Program Files¥Toshiba¥Parcel Maker

A "ParcelMaker¥logs" folder will be also created under the [Temp] directory for the current user on your computer to record log of errors causing during executing ParcelMaker. An error log file will be named like "log[yyyymmdd].txt", where "yyyymmdd" represents the date when errors occur.

A program menu "Parcel Maker" will be also created while installation. The menu contains shortcuts to folders which may be sometimes accessed by a user and a shortcut to this user manual.

After the installation process has finished, a [Parcel Maker] folder will be generated under the Windows start menu. The folder contains folder/file shortcuts listed in Table 1.

<div align="center">

Table 1: Start menu of ParcelMaker

</div>

<table border="1"><tr><td>Shortcut name</td><td>Description</td></tr><tr><td>Addin</td><td>Shortcut to the [Addin] folder which contains ParcelMaker itself and its related files. License file explained in the next subclause shall be placed on the folder.</td></tr><tr><td>Log</td><td>Shortcut to the [Log] folder which contains daily reports of errors caused on ParcelMaker.</td></tr></table>

## 3.3. Getting License File

The use of ParcelMaker Community Edition is permitted only for licensed users. Whenever ParcelMaker is started, it checks the license key assigned to your computer. There are two kinds of license, one is (1) a personal license which has no limitation and the other is (2) a group license which has the expiration date. Both of them will be published by the following software publishers, so please contact either.

$$
\mathrm {a k i r a . h o s o k a w a @ t o s h i b a . c o . j p}
$$

If you get a personal license for your computer, you need to inform the publisher of the MAC address of the primary Ethernet adapter of your computer. To get the MAC address of your computer, you should open up a command prompt and type the command "ipconfig /all". This command will return information about the Ethernet adapter of your computer and a "Physical Address" in the form "xx-xx-xx-xx-xx-xx". This Physical Address is the MAC address (see Figure 2).

After copying a license file to the Addin folder under the installation directory, ParcelMaker will be activated.

![](page=6,bbox=[292, 1364, 1693, 2349])

<div align="center">

Figure 2: Example of a MAC address

</div>

## 3.4. Registering ParcelMaker as an add-in of Excel

This subclause explains how to register ParcelMaker as an add-in of Excel to start it. Setup the security option of Excel as follows:

A boot MS Excel,

B press the [Office button] and select [Excel Options] on the bottom

C on the bottom of the new menu select [Excel Add-ins] from the drop-down list below the [Manage] table and click the [Go...] button (Figure 3),

D click the [Browse...] button and select the ParcelMaker.xla in the Addin folder of ParcelMaker (),

E click the OK button on the [Add-Ins] form, and

F reboot MS Excel.

![](page=7,bbox=[408, 1054, 1571, 1997])

<div align="center">

Figure 3: Load [Add-ins] form

</div>

After registering ParcelMaker as an add-in of MS Excel, the menu [Parcel Maker] will be displayed on the menu bar for Excel 2003. For Excel 2007 and Excel 2010, the menu will be under the "Add-Ins" menu on the menu bar. If there is no license file found, or the license file is invalid, then ParcelMaker will show a pop-up alert and the menu will not be activated.

## 4. ParcelMaker Workbook

## 4.1. General

ParcelMaker only works for Excel workbooks and worksheets which are generated by ParcelMaker itself.

## 4.2. Making ParcelMaker workbook

A ParcelMaker workbook is gotten through a function loaded via the menu [ParcelMaker] $ \rightarrow $ [File] $ \rightarrow $ [New]. Those worksheets will be automatically generated through the process. In this document, such a workbook is called as "ParcelMaker workbook".

## 4.3. Structure of ParcelMaker workbook

Each ParcelMaker workbook consists of the following worksheets.

- "pcls_LOCAL" sheet, which contains a list of data dictionaries stored in the workbook,

- "project" sheet, which contains language codes applied to the ParcelMaker workbook,

- "sheetmap" sheet, which contains a set of sheet information on the ParcelMaker workbook,

- parcel sheets for data dictionaries,

- parcel sheets for instances,

- 4. 4. Exchanging ParcelMaker workbook

- other worksheets which are generated by a user.

A ParcelMaker workbook can be exchanged with another computer.

## 5. Data Dictionary

## 5.1. General

Each ParcelMaker workbook can contain the content of one or plural data dictionaries. In accordance with IEC 62656-1, each data dictionary is represented by using 11 parcel sheets at maximum, i.e., dictionary, supplier, class, property, enumeration, term, datatype, document, UoM and relation sheets. ParcelMaker provides a function for generating such parcel sheets from scratch.

## 5.2. Generating Data Dictionary from Scratch

The function can be loaded via the menu [ParcelMaker] $ \rightarrow $ [Dictionary] $ \rightarrow $ [Add New Dictionary]. Figure 4 is a form which is shown by using the function.

![](page=9,bbox=[287, 337, 1694, 981])

<div align="center">

Figure 4: [Add dictionary] form for loading CSV data

</div>

The [Parcel ID] on the top of the form gives a field for an identifier of data parcels for distinguishing between dictionaries in a workbook. The value of this field is used for the base of each worksheets. For example, if "IEC61360-4" is set to this field, the default sheet name of a class sheet is set as "IEC61360-4_CLASS".

Parcel sheets of checked categories of ontological entities will be generated. For example, if Enumeration and Term are checked, worksheets for those entities will be generated. Note that Class and Property are essential for representing a data dictionary, therefore, those categories are always generated.

At the same time of the generation of a parcel sheet, a workbook file or a CSV file which contains an IEC 62656-1 compliant data can be imported into the worksheet by specifying the directory of the file.

NOTE: A CSV file is read using the character encoding defined in the [System environment] form. If the imported data is garbled, either change the character encoding of the file or change the setting in the [System environment] form as described in the section 12.5.

The [Change] button in the [Language setting] frame is for setting a source language and other languages to be translated for a new dictionary. Section 12.4 describes how to use this function.

After pressing the [Add] button, ParcelMaker will generate sheets for all checked meta-classes. The dictionary name will be added into the "pcls_LOCAL" sheet.

## 5.3. Adding a meta-class sheet to the existing data dictionary

There are the following two ways to add a sheet for a meta-class to the existing dictionary.

a) From scratch: load a form for selecting meta-classes whose sheets to be generated shown as in Figure 4. Then, sheets for the checked meta-classes will be automatically generated. Note that the target dictionary will be a

b) Activation: If you have generated a sheet by yourself (that means the sheet is one which was not generated by the step "a”), select the menu [Parcel Maker] $ \rightarrow $ [Dictionary] $ \rightarrow $ [Activate current sheet]. Then, a dictionary list will be shown in the pop-up windows, so select a dictionary in which the sheet should be activated.

## 5.4. Deleting Data Dictionary from ParcelMaker Workbook

When you delete a dictionary from a workbook, select the menu [Parcel Maker] $ \rightarrow $ [Dictionary] $ \rightarrow $ [Delete dictionary]. Then, a pop-up window will be shown and sheets regarding a selected dictionary will be automatically removed from the workbook. Note that the menu will be enabled when the dictionary list sheet is active.

## 6. Parcel sheet

## 6.1. Overview

According to IEC 62656-1, each parcel sheet consists of 2 parts; a header section and a data section. The header section also consists of 2 parts; a class header section and a schema header section. For describing an ontological element or an instance, you should edit cells in a row in the data section.

<table class="table table-bordered"><thead><tr><th></th><th>A</th><th>B</th><th>C</th><th>D</th><th>E</th><th>F</th><th>G</th></tr></thead><tbody><tr><td>1</td><td colspan="7">#CLASS_ID:=MDC_C002</td></tr><tr><td>2</td><td colspan="7">#CLASS_NAME.en:=Class meta-class</td></tr><tr><td>3</td><td colspan="7">#SOURCE_LANGUAGE:=en</td></tr><tr><td>4</td><td colspan="7">#DEFAULT_SUPPLIER:=0112/2///62656_1</td></tr><tr><td>5</td><td colspan="7">#DEFAULT_VERSION:=1</td></tr><tr><td>6</td><td>#PROPE</td><td colspan="2">MDC_P001_5</td><td>MDC_P002</td><td>MDC_P002</td><td>MDC_P003</td><td>MDC_P003</td></tr><tr><td>7</td><td>#PROPE</td><td>Code</td><td></td><td>Version nu</td><td>Revision nu</td><td>Date of orig</td><td>Date of cur</td></tr><tr><td>8</td><td>#DATATY</td><td colspan="2">STRING_TYPE</td><td>STRING_T</td><td>STRING_T</td><td>STRING_T</td><td>STRING_T</td></tr><tr><td>9</td><td>#UNIT</td><td></td><td></td><td></td><td></td><td></td><td></td></tr><tr><td>10</td><td>#DEFAULT</td><td colspan="2">IECSC65</td><td></td><td></td><td></td><td></td></tr><tr><td>11</td><td>#DEFAULT</td><td colspan="2">1</td><td></td><td></td><td></td><td></td></tr><tr><td>12</td><td>#REQUIR</td><td colspan="2">KEY</td><td></td><td>MAND</td><td>MAND</td><td>MAND</td></tr><tr><td>13</td><td colspan="3">SC65E_ROOT</td><td>1</td><td>1</td><td></td><td></td></tr><tr><td>14</td><td colspan="3">AAA005</td><td>1</td><td>1</td><td></td><td></td></tr><tr><td>15</td><td colspan="3">AAA011 comment</td><td>1</td><td>1</td><td></td><td></td></tr><tr><td>16</td><td colspan="3">AAA003</td><td>1</td><td>1</td><td></td><td></td></tr><tr><td>17</td><td>#</td><td></td><td>comment</td><td>comment</td><td></td><td></td><td></td></tr><tr><td>18</td><td></td><td colspan="2">AAA006</td><td>1</td><td>Z</td><td></td><td></td></tr></tbody></table>

## 6.2. Comment out

In the data section of each parcel sheet, if the value of the first cell of a row starts with the number sign "#", the row is treated as comment row by ParcelMaker. On a comment row, any operation is ignored.

If a string which starts with the number sign "#" is set on the first cell of a row, the font colour of all cells of the row is changed into green for indicating that the row is commented out. If any leading number sign "#" is removed from the value of the first cell of a row, the font colour of all cells of the row is changed into black.

![](page=12,bbox=[457, 879, 1635, 1762])

<div align="center">

Figure 5: Structure of a worksheet

</div>

## 7. Identifier for an ontological element

The syntax for an identifier of an ontological element complies with the rules for an ICID (International Concept IDentifier), which is defined in the IEC62656-1. The basic syntax of an ICID is as follows:

$$
\mathrm {I C I D}::= < \mathrm {s u p p l i e r} > \# < \mathrm {c o d e} > \# \# < \mathrm {v e r s i o n} > \# \# \# < \mathrm {c o m m e n t} >
$$

ParcelMaker supports shorthand notation of ICID defined in IEC 62656-1 in both header section and header section.

NOTE: The modification of a default value does not automatically apply to the data section. So, you should modify each value manually.

## 8. Editing cell column values

## 8.1. Real-time validation

When a value is entered into a cell in a cell column, ParcelMaker immediately checks if the syntax of the value complies with data type, value format and pattern constraint for that cell column. If the value does not comply with one of the above rules, the font colour of the cell turns red. For dictionary sheets, the syntax of an identifier will be also checked.

<div align="center">

NOTE: If colour change for an invalid value is interfering for you, see subclause 12.2 to disable the function.

</div>

![](page=14,bbox=[459, 1006, 1553, 1930])

<div align="center">

Figure 6: Real-time validation

</div>

## 8.2. Special GUIs for meta-properties

## 8.2.1. General

There are meta-properties whose identifiers are displayed in blue text in the #PROPERTY_ID line. ParcelMaker provides special GUIs for such meta-properties to help easily viewing or describing their values. The following lists such meta-properties.

- Synonymous name (MDC_P004_2) $ \rightarrow $ 8.2.2

- Superclass (MDC_P010) $ \rightarrow $ 8.2.3

- Is case of (MDC_P013) $ \rightarrow $ 8.2.4

- Applicable properties (MDC_P014) $ \rightarrow $ 8.2.5

- Applicable types ( MDC_P015) $ \rightarrow $ 8.2.5

- Definition class (MDC_P021) $ \rightarrow $ 8.2.7

- Data type (MDC_P022) $ \rightarrow $ 8.2.8

- Unit in SGML (MDC_P023_2) $ \rightarrow $ 8.2.9

- Value format (MDC_P024) $ \rightarrow $ 8.2.10

- Condition (MDC_P028) $ \rightarrow $ 8.2.11

- DET classification (MDC_P040) $ \rightarrow $ 8.2.12

- Code for unit (MDC_P041) $ \rightarrow $ 8.2.13

- Codes for alternative units (MDC_P042) $ \rightarrow $ 8.2.13

- Enumerated list of terms (MDC_P043) $ \rightarrow $ 8.2.14

- Imported properties (MDC_P090) $ \rightarrow $ 8.2.6

- Imported types (MDC_P091) $ \rightarrow $ 8.2.6

- Imported documents (MDC_P093) $ \rightarrow $ 8.2.6

- Applicable documents (MDC_P094) $ \rightarrow $ 8.2.5

- Domain of the relation (MDC_P201) $ \rightarrow $ 8.2.15

- Domain of the function (MDC_P202) $ \rightarrow $ 8.2.15

- Quantity (MDC_P114) $ \rightarrow $ 8.2.13

- ENUM_TYPE properties (for instance sheets) $ \rightarrow $ 0

Every GUI will be loaded by double-click in a cell in data section. In this subsection hereinafter, how to use each GUI for each meta-property will be explained.

NOTE: If a double-click action is interfering for you, see subclause 12.2 to disable the function.

## 8.2.2. Synonymous name (MDC_P004_2)

The [Synonymous name] form consists of the following components.

- Listview $ \rightarrow $ show a list of synonymous names

- [Add] button $ \rightarrow $ add a synonymous name into the listview.

- [Edit] button $ \rightarrow $ modify a synonymous name on the selected row in the listview.

- [Delete] button $ \rightarrow $ delete a synonymous name on the selected row in the listview.

- [OK] button $ \rightarrow $ enter a set of synonymous names as well-formed value into the cell (e.g., {(Flow meter,en)})

- [Cancel] button $ \rightarrow $ close the form without any change.

![](page=16,bbox=[675, 887, 1307, 1511])

<div align="center">

Figure 7: Synonymous name form

</div>

## 8.2.3. Superclass (MDC_P010)

The [Superclass] form consists of the following components.

- Combo box $ \rightarrow $ show the identifier of the active dictionary.

- Text field and [Search] button $ \rightarrow $ Search a class in the tree view by a keyword. If there is a matched class, such a class will be focused.

- Tree view $ \rightarrow $ show the class structure of the dictionary.

- [OK] button $ \rightarrow $ enter the identifier of a selected class into the cell.

- [Cancel] button $ \rightarrow $ close the form without any change.

NOTE: If a superclass of a class is invalid, ParcelMaker assumes the superclass to be "UNIVERSE", and continues to display a class tree.

![](page=17,bbox=[561, 1051, 1422, 1884])

<div align="center">

Figure 8: [Superclass] form

</div>

## 8.2.4. Is case of (MDC_P013)

The [Is case of] form consists of the following components.

- Combo box $ \rightarrow $ change the dictionary from which a property may be imported.

- Tree view $ \rightarrow $ show the class structure of the specified dictionary.

- List box $ \rightarrow $ show a set of "case of" classes.

- Text field and [Search] button $ \rightarrow $ Search a class in the tree view by a keyword. If there is a matched class, such a class will be focused.

- [Add] button $ \rightarrow $ add a selected class in the tree view into the list box.

- [Delete] button $ \rightarrow $ delete a selected class from the list box.

- [OK] button $ \rightarrow $ enter a set of "case of" classes as well-formed value into the cell.

- [Cancel] button $ \rightarrow $ close the form without any change.

NOTE: If a superclass of a class is invalid, ParcelMaker assumes the superclass to be "UNIVERSE", and continues to display a class tree.

![](page=18,bbox=[472, 1199, 1511, 1974])

<div align="center">

Figure 9: [Is case of] form

</div>

## 8.2.5. Applicable properties, types and documents (MDC_P014, MDC_P015 and MDC_P094)

The [Applicable] form consists of the following components.

- Native applicable list view $ \rightarrow $ show a list of native applicable properties, data types or documents.

- Visible but non applicable list view $ \rightarrow $ show a list of visible but non applicable properties, data types or documents.

- Known applicable list view $ \rightarrow $ show a known applicable properties, data types, or documents. This area is hidden whenever the form is loaded.

- [Add] button $ \rightarrow $ add a selected item on the visible but non applicable list view to the native applicable list view.

- [Delete] button $ \rightarrow $ delete a selected item on the native applicable list view.

- [Up] button $ \rightarrow $ move selected items up on the native applicable list view.

- [Down button] $ \rightarrow $ move selected items down on the native applicable list view.

- [More] and [Less] buttons $ \rightarrow $ show/hide the area for the known applicable list view.

- [OK] button $ \rightarrow $ enter a list of items on the native applicable list view as well-formed value into the cell.

- [Cancel] button $ \rightarrow $ close the form without any change.

![](page=19,bbox=[370, 1536, 968, 1940])

![](page=19,bbox=[392, 1970, 979, 2349])

<table class="table table-bordered"><thead><tr><th>Code</th><th colspan="2">Name</th><th>DataType</th><th>UNIT</th></tr><tr><th>Ent...</th><th>Enter text here</th><th>Enter text here</th><th>E...</th><th></th></tr></thead><tbody><tr><td>AAF157</td><td>common-mode in...</td><td>LEVEL(MAX) OF ...</td><td>V</td><td></td></tr><tr><td>AAF160</td><td>common-mode re...</td><td>LEVEL(MIN,TYP,...</td><td>dB</td><td></td></tr><tr><td>AAF163</td><td>differential i...</td><td>LEVEL(MIN) OF ...</td><td>ohm</td><td></td></tr><tr><td>AAF164</td><td>common-mode in...</td><td>LEVEL(MIN) OF ...</td><td>ohm</td><td></td></tr><tr><td>AAF192</td><td>coupling method</td><td>ENUM_CODE_TYPE...</td><td></td><td></td></tr><tr><td>AAF158</td><td>output voltage...</td><td>LEVEL(MIN) OF ...</td><td>V</td><td></td></tr><tr><td>AAF159</td><td>large-signal v...</td><td>LEVEL(MIN) OF ...</td><td>1</td><td></td></tr><tr><td>AAF162</td><td>slew rate</td><td>LEVEL(MIN) OF ...</td><td>V/s</td><td></td></tr><tr><td>AAF165</td><td>output resistance</td><td>LEVEL(TYP) OF ...</td><td>ohm</td><td></td></tr><tr><td>AAF166</td><td>unity-gain fre...</td><td>LEVEL(MIN) OF ...</td><td>Hz</td><td></td></tr><tr><td>AAF167</td><td>gain bandwidth...</td><td>LEVEL(MIN) OF ...</td><td>Hz</td><td></td></tr><tr><td>AAF168</td><td>total response...</td><td>LEVEL(MAX) OF ...</td><td>s</td><td></td></tr><tr><td>AAF191</td><td>input configur...</td><td>ENUM_CODE_TYPE...</td><td></td><td></td></tr><tr><td>AAF189</td><td>amplified quan...</td><td>ENUM_CODE_TYPE...</td><td></td><td></td></tr><tr><td>AAE697</td><td>current consum...</td><td>LEVEL(MIN,TYP,...</td><td>A</td><td></td></tr><tr><td>AAE969</td><td>amplifier package</td><td>STRING_TYPE</td><td></td><td></td></tr><tr><td>AAE974</td><td>input standing...</td><td>LEVEL(MAX) OF ...</td><td>1</td><td></td></tr><tr><td>AAE975</td><td>output standin...</td><td>LEVEL(MAX) OF ...</td><td>1</td><td></td></tr><tr><td>AAF146</td><td>frequency appl...</td><td>ENUM_CODE_TYPE...</td><td></td><td></td></tr><tr><td>AAE002</td><td>category EE co...</td><td>ENUM_CODE_TYPE...</td><td></td><td></td></tr><tr><td>AAE007</td><td>terminal shape</td><td>ENUM_CODE_TYPE...</td><td></td><td></td></tr><tr><td>AAE008</td><td>terminal place...</td><td>ENUM_CODE_TYPE...</td><td></td><td></td></tr><tr><td>AAE023</td><td>terminal diameter</td><td>LEVEL(MIN,NOM,...</td><td>m</td><td></td></tr></tbody></table>

<div align="center">

Figure 10: [Applicable] form with known applicable properties

</div>

8. 2.6. Imported properties, types and documents (MDC_P090, MDC_P091 and MDC_P093)

The [Imported] form consists of the following components.

- Imported item list view $ \rightarrow $ show a list of imported properties, data types or documents.

- Selectable item list view $ \rightarrow $ show a list of properties which the "case" of classes have and which can be imported to the class.

- [Add] button $ \rightarrow $ add a selected item on the visible but non applicable list view to the native applicable list view.

- [Delete] button $ \rightarrow $ delete a selected item on the native applicable list view.

- [Up] button $ \rightarrow $ move selected items up on the native applicable list view.

- [Down button] $ \rightarrow $ move selected items down on the native applicable list view.

- [OK] button $ \rightarrow $ enter a list of items on the imported item list view as well-formed value into the cell.

- [Cancel] button $ \rightarrow $ close the form without any change.

![](page=20,bbox=[568, 1184, 1420, 2348])

<div align="center">

Figure 11: [Imported] form

</div>

## 8.2.7. Definition class (MDC_P021)

The [Definition class] form consists of the following components.

- Combo box $ \rightarrow $ show the identifier of the active dictionary.

- Text field and [Search] button $ \rightarrow $ Search a class in the tree view by a keyword. If there is a matched class, such a class will be focused.

- Tree view $ \rightarrow $ show the class structure of the dictionary.

- [OK] button $ \rightarrow $ enter the identifier of a selected class into the cell.

- [Cancel] button $ \rightarrow $ close the form without any change.

NOTE: If a superclass of a class is invalid, ParcelMaker as assumes it to be "UNIVERSE", and continues to display a class tree.

![](page=21,bbox=[562, 1051, 1420, 1885])

<div align="center">

Figure 12: [Definition class] form

</div>

## 8.2.8. Data type (MDC_P022)

The [Data type] form consists of the following basic components.

- Category combo box (left hand side) $ \rightarrow $ list categories of data types.

- Data type combo box (right hand side) $ \rightarrow $ list data types of the selected category.

NOTE 1: The structure of the other area in the form will be changed in accordance with the selection in the category combo box.

NOTE 2: Nested aggregation is allowed up to 3 levels.

![](page=22,bbox=[420, 944, 1597, 1574])

<div align="center">

Figure 13: An example of the [DataType] form for ENUM_TYPE

</div>

![](page=22,bbox=[491, 1711, 1510, 2362])

<div align="center">

Figure 14: An example of the [DataType] form for aggregate type

</div>

## 8.2.9. Unit in SGML (MDC_P023_2)

The [MathML Viewer] form consists of the following components.

- MathML text field (left hand side) $ \rightarrow $ show the MathML text

- Rendered Math field (right hand side) $ \rightarrow $ show the math representation for the MathML text described in the MathML text field.

- [OK] button $ \rightarrow $ enter the MathML text, which is described in the MathML text field, into the cell.

- [Cancel] button $ \rightarrow $ close the form without any change.

NOTE: ParcelMaker uses the online service of MathJax, which is provided via http://www.mathjax.org/. If the Internet is not available, no text will be shown in the rendered Math field.

![](page=23,bbox=[423, 1137, 1562, 1799])

<div align="center">

Figure 15: [MathML Viewer] form

</div>

## 8.2.10. Value format (MDC_P024)

The [Preset value format] form consists of the following component.

- List box $ \rightarrow $ show preset candidates of value format for the specified data type. When double-clicking one of the candidates, it will be entered into the cell.

NOTE : In the case that there is no value format in the list, enter a value into the cell directly.

![](page=24,bbox=[824, 776, 1160, 1088])

<div align="center">

Figure 16: [Preset value format] form

</div>

## 8.2.11. Condition (MDC_P028)

The [Condition] form consists of the following components.

- Condition property list view $ \rightarrow $ show a list of condition properties.

- Selectable property list view $ \rightarrow $ show a list of properties which can be selected as condition properties.

- [Add] button $ \rightarrow $ add a selected property on the selectable property list view to the condition property list view.

- [Delete] button $ \rightarrow $ delete a selected property on the condition property list view.

- [Up] button $ \rightarrow $ move selected properties up on the condition property list view.

- [Down button] $ \rightarrow $ move selected properties down on the condition property list view.

- [OK] button $ \rightarrow $ enter a list of properties on the condition property list view as well-formed value into the cell.

- [Cancel] button $ \rightarrow $ close the form without any change.

Condition

![](page=25,bbox=[657, 1290, 1359, 1695])

<div align="center">

Selectable properties

</div>

<table class="table table-bordered"><thead><tr><th>Code</th><th colspan="2">Name</th><th>Data type</th><th>Unit</th></tr></thead><tbody><tr><td>Ent...</td><td>Enter text here</td><td>Enter text here</td><td>E...</td><td>T</td></tr><tr><td>AAD0...</td><td>die identifier</td><td>STRING TYPE</td><td></td><td></td></tr><tr><td>AAD0...</td><td>die name</td><td>STRING TYPE</td><td></td><td></td></tr><tr><td>AAD0...</td><td>die version</td><td>STRING TYPE</td><td></td><td></td></tr><tr><td>AAD0...</td><td>die type code</td><td>ENUM CODE TYP...</td><td></td><td></td></tr><tr><td>AAD0...</td><td>substrate material</td><td>STRING TYPE</td><td></td><td></td></tr><tr><td>AAD0...</td><td>connection require...</td><td>ENUM CODE TYP...</td><td></td><td></td></tr><tr><td>AAD0...</td><td>organization name</td><td>STRING TYPE</td><td></td><td></td></tr><tr><td>AAD0...</td><td>die test level code</td><td>STRING TYPE</td><td></td><td></td></tr><tr><td>AAD0...</td><td>die yield</td><td>LEVEL(MIN,TYP) O...</td><td></td><td></td></tr></tbody></table>

## 8.2.12. DET classification (MDC_P040)

The [DET Classification] form consists of the following components.

- Category list view $ \rightarrow $ show the DET classification categories.

- Classification code list view $ \rightarrow $ show the list of classification codes for the specified category.

- [OK] button $ \rightarrow $ enter the classification code which is selected in the classification code list into the cell.

- [Cancel] button $ \rightarrow $ close the form without any change.

![](page=26,bbox=[356, 882, 1633, 1695])

<div align="center">

Figure 17: [DET classification] form

</div>

8. 2.13. Code for unit, Codes for alternative units and Quantity (MDC_P041, MDC_P042 and MDC_P114)

The [Select UoMs] form consists of the following components.

- Quantity list view $ \rightarrow $ show a list of quantities.

- UoM list view $ \rightarrow $ show a list of UoMs of the specified quantity. In each row, the first checkbox is for specifying the primary unit, and the second checkbox is for selecting its alternative units.

- [Up] button $ \rightarrow $ move selected properties up on the UoM list view.

- [Down button] $ \rightarrow $ move selected properties down on the UoM list view.

- [OK] button $ \rightarrow $ enter the identifier of the UoM into the MDC_P041 cell, whose first checkbox is checked. If there is the MDC_P042 column, enter a set of the identifiers of the UoMs into the MDC_P042 cell, whose second checkboxes are checked. Moreover, If there is the MDC_P114 column, enter the identifier of the quantity into the MDC_P114 cell, which is selected in the quantity list view.

- [Cancel] button $ \rightarrow $ close the form without any change.

![](page=27,bbox=[320, 1311, 1665, 2169])

<div align="center">

Figure 18: [Select UoMs] form

</div>

## 8.2.14. Enumerated list of terms (MDC_P043)

The [Select terms] form consists of the following components.

- Applicable term list view $ \rightarrow $ show a list of terms which will be applied to the enumeration.

- Selectable term list view $ \rightarrow $ show a list of terms which can be selected.

- [Add] button $ \rightarrow $ add a selected term on the selectable term list view to the applicable term list view.

- [Delete] button $ \rightarrow $ delete a selected term on the applicable term list view.

- [Up] button $ \rightarrow $ move selected terms up on the applicable term list view.

- [Down button] $ \rightarrow $ move selected terms down on the applicable term list view.

- [OK] button $ \rightarrow $ enter a list of terms on the applicable term list view as well-formed value into the cell.

- [Cancel] button $ \rightarrow $ close the form without any change.

![](page=28,bbox=[459, 1179, 1524, 2178])

<div align="center">

Figure 19: [Select terms] form

</div>

## 8.2.15. Domain of the relation/function (MDC_P201 and MDC_P202)

The [Domain editor] form consists of the following components.

- Domain list view $ \rightarrow $ show a list of items which will be the domain of the relation.

- Selectable list view $ \rightarrow $ show a list of items of each meta-class which can be selected.

- [Add] button $ \rightarrow $ add a selected item on the selectable list view to the domain list view.

- [Delete] button $ \rightarrow $ delete a selected item on the domain list view.

- [Up] button $ \rightarrow $ move selected items up on the domain list view.

- [Down button] $ \rightarrow $ move selected items down on the domain list view.

- [OK] button $ \rightarrow $ enter a list of items on the domain list view as well-formed value into the cell.

- [Cancel] button $ \rightarrow $ close the form without any change.

![](page=29,bbox=[461, 1012, 1521, 2217])

<div align="center">

Figure 20: [Domain editor] form

</div>

## 8.2.16. ENUM_TYPE property

For attributes and properties whose data type is one of ENUM_TYPEs, the selectable value codes and their preferred names are listed in an Excel comment on the cell in the "#DATATYPE" row (Figure 21). The comment is usually minimized and displayed when the cursor is placed over the cell.

![](page=30,bbox=[474, 641, 1530, 1457])

<div align="center">

Figure 21: List of selectable values displayed in an Excel comment

</div>

Additionally, when double-clicking on a cell in the data section that is in a cell column whose data type is one of the enumeration data types, a enumeration list form like that shown in Figure 22 is displayed. The selectable values and their preferred names are listed in the form. On double-clicking on one of the values, the value is entered into the cell.

![](page=31,bbox=[477, 342, 1526, 1157])

<div align="center">

Figure 22: Enumeration list form

</div>

## 9. Viewer

## 9.1. Class viewer

ParcelMaker gives GUI for looking at both structural and semantic information. The GUI will be loaded by a right-hand click menu [Class viewer] in the data section of the class sheet. A class described in the line right-clicked will be a target class for the form. This form can be resized by dragging and dropping the edge of the form. Besides, font size of text in each area can be resized by pushing smaller/larger buttons on the form.

The ClassViewer gives a view of two kinds of class structures, one is a classification tree shown as in Figure 23 and the other is a composition tree shown as in Figure 24. In both cases, a tree structure will be displayed at the left hand side, and information of the selected item in the tree view will be displayed at the right hand side.

In the case of the classification tree viewer shown as in Figure 23, the class information and the list of the properties of the selected class in the tree view will be displayed at the right hand side area. There are check boxes at the right hand side area which show/hide the information regarding the label of each check box.

![](page=32,bbox=[288, 1494, 1698, 2337])

<div align="center">

Figure 23: Class viewer (Classification tree)

</div>

In the case of the composition tree view shown as in Figure 24, both class and property are displayed in the tree view at the left hand side. If a class is selected in the tree view, the same kind of information as the classification tree view will be displayed at the right hand side. If a property is selected in the tree view, the information of the selected property will be displayed at the right hand side.

![](page=33,bbox=[286, 659, 1699, 1499])

<div align="center">

Figure 24: Class viewer (Composition tree)

</div>

For classification tree view, the [Create instance sheet] button is given to generate a parcel sheet shown as in Figure 25 for describing instances of a class selected on the classification tree view.

![](page=34,bbox=[415, 351, 1572, 1151])

<div align="center">

Figure 25: Parcel sheet for instances

</div>

For composition tree view, the [Output to sheet] button is given to generate a composition view sheet of the target class shown as in Figure 26. The composition view sheet consists of tree viewer (A) and information viewer of each line for enumerated code (B), unit (C), property identifier (D) and class identifier (E).

![](page=35,bbox=[351, 360, 1651, 1256])

<div align="center">

Figure 26: Composition view sheet

</div>

## 9.2. Relation viewer

ParcelMaker gives GUI for looking at the relation structure. The GUI will be loaded by a right-hand click menu [Relation viewer] in the data section of the relation meta-class sheet. Figure 27 gives an example of a form for relation viewer. The relation tree is displayed at the left hand side, while information of the relation selected in the tree is displayed at the right hand side.

A relation tree is constructed by relationships between relations which are described in either a MDC_P201 (Domain of the function) column or a MDC_P202 (Domain of the relation) column. Items listed on a table on the bottom in the relation information field are also extracted from either column. A table in each tab will be updated when a relation selection on the tree is changed.

There is the special button named "CIM/RDF", which is used to output a CIM/RDF file including ontological elements related to checked packages on the relation tree.

![](page=36,bbox=[352, 1171, 1631, 2000])

<div align="center">

Figure 27: Relation viewer

</div>

## 10. Instance data generation

ParcelMaker has a function to generate instance data by combination of one or more groups of sets of property values. This section explains the steps using an example.

The function is available only for an instance sheet. When the instance sheet is active, the submenu for instance data generation (i.e. [Parcel Maker] $ \rightarrow $ [Generate instance] $ \rightarrow $ [rule]) is enabled.

On clicking on the submenu, a worksheet for editing combination rules is generated in the workbook as in Figure 28. The structure of the worksheet resembles that of the instance worksheet, but contains two extra columns after the last cell column in the worksheet for setting combination rules. Each group of sets of property values has to be defined in the worksheet.

![](page=37,bbox=[465, 1238, 1518, 2182])

<div align="center">

Figure 28: Example of a worksheet for setting generation rules

</div>

Figure 29 shows an example of groups of sets of values for properties defined in the workbook shown in Figure 28. In, An identifier for a group, consisting only of alphabet letters or numerals, has to be defined in the instruction column in the data section. In this example, there are 3 groups:

- the first group whose identifier is 1 containing two sets of values for the property in the second column (Column B), i.e. "Active" and "Passive",

- the second group whose identifier is 2 containing three sets of values for the property in the sixth column (Column F), i.e. "IPS", "VA" and "TN", and

- the third group whose identifier is 3 containing two sets of values of the property in the fourth column (Column D), i.e. "21" and "24".

Each value in each of these groups is also assigned a sequential line number in the form LINEnn in the second SYSTEM column, where nn is a sequential number starting from 1.

![](page=38,bbox=[465, 1121, 1515, 2060])

<div align="center">

Figure 29: Example of groups of sets of property values

</div>

After setting the groups, instance data will be automatically generated through the submenu of ParcelMaker (i.e. [Parcel Maker] $ \rightarrow $ [Generate instance] $ \rightarrow $ [execute]). In the example of Figure 29, 12 instances are generated and entered into in a new instance sheet as in Figure 30.

<table class="table table-bordered"><thead><tr><th></th><th>A</th><th>B</th><th>C</th><th>D</th><th>E</th><th>F</th><th>G</th><th>H</th><th>I</th></tr></thead><tbody><tr><td>1</td><td colspan="10">#DICTIONARY ID:=ECALS v9.1</td></tr><tr><td>2</td><td colspan="10">#CLASS_ID:=147/101001#XJA901##1</td></tr><tr><td>3</td><td colspan="10">#CLASS_NAME.en:=MATRIX LIQUID CRYSTAL DISPLAY</td></tr><tr><td>6</td><td colspan="10">#ALTERNATE_CLASSID:=</td></tr><tr><td>7</td><td colspan="10">#SOURCE_LANGUAGE:=</td></tr><tr><td>8</td><td colspan="10">#CONTENT_ID:=</td></tr><tr><td>11</td><td colspan="10">#DEFAULT_SUPPLIER:=</td></tr><tr><td>13</td><td>#PROPER</td><td>147/10100</td><td>147/10100</td><td>147/10100</td><td>147/10100</td><td>147/10100</td><td>147/10100</td><td>147/10100</td><td>147/10100</td></tr><tr><td>15</td><td>#PROPER</td><td>Drive type</td><td>Screen siz</td><td>Screen siz</td><td>Outline of</td><td>LCD mode</td><td>Number of</td><td>Number. o</td><td>Color pi</td></tr><tr><td>18</td><td>#DATATYP</td><td>ENUM_CO</td><td>LEVEL(NO)</td><td>LEVEL(NO)</td><td>STRING_T</td><td>ENUM_CO</td><td>LEVEL(NO)</td><td>STRING_T</td><td>ENUM_CO</td></tr><tr><td>19</td><td>#UNIT</td><td></td><td></td><td></td><td></td><td></td><td>pixel</td><td></td><td></td></tr><tr><td>23</td><td>#VALUE_F</td><td>X.17</td><td>NR3 S..7.7</td><td>NR3 S..7.7</td><td>M..512</td><td>X.17</td><td>NR1 S..10</td><td>M..512</td><td>X.17</td></tr><tr><td>25</td><td colspan="10">#REQUIREMENT</td></tr><tr><td>26</td><td></td><td>Active</td><td></td><td>21</td><td></td><td>IPS</td><td></td><td></td><td></td></tr><tr><td>27</td><td></td><td>Passive</td><td></td><td>21</td><td></td><td>IPS</td><td></td><td></td><td></td></tr><tr><td>28</td><td></td><td>Active</td><td></td><td>21</td><td></td><td>VA</td><td></td><td></td><td></td></tr><tr><td>29</td><td></td><td>Passive</td><td></td><td>21</td><td></td><td>VA</td><td></td><td></td><td></td></tr><tr><td>30</td><td></td><td>Active</td><td></td><td>21</td><td></td><td>TN</td><td></td><td></td><td></td></tr><tr><td>31</td><td></td><td>Passive</td><td></td><td>21</td><td></td><td>TN</td><td></td><td></td><td></td></tr><tr><td>32</td><td></td><td>Active</td><td></td><td>24</td><td></td><td>IPS</td><td></td><td></td><td></td></tr><tr><td>33</td><td></td><td>Passive</td><td></td><td>24</td><td></td><td>IPS</td><td></td><td></td><td></td></tr><tr><td>34</td><td></td><td>Active</td><td></td><td>24</td><td></td><td>VA</td><td></td><td></td><td></td></tr><tr><td>35</td><td></td><td>Passive</td><td></td><td>24</td><td></td><td>VA</td><td></td><td></td><td></td></tr><tr><td>36</td><td></td><td>Active</td><td></td><td>24</td><td></td><td>TN</td><td></td><td></td><td></td></tr><tr><td>37</td><td></td><td>Passive</td><td></td><td>24</td><td></td><td>TN</td><td></td><td></td><td></td></tr><tr><td>38</td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td></tr></tbody></table>

<div align="center">

Figure 30: Example of instance data automatically generated

</div>

When there is a combination of sets among the groups which is NOT applied, it can be be set in the [Exception] form as in Figure 31. This form is loaded through a hyperlink in the instruction column in the data section.

![](page=39,bbox=[800, 1721, 1327, 2295])

<div align="center">

Figure 31: The [Exception] form

</div>

## 11. Data exchange

## 11.1. Export

11. 1.1. Exporting the active worksheet into another file

ParcelMaker has a function to export the data in the active worksheet into another file. Supported file types are text (".csv", ".txt" and ".pcl") and Excel book (".xls" and ".xlsx").

The function is available only for dictionary sheets and instance sheets, and is called through a submenu of ParcelMaker (i.e. [Parcel Maker] $ \rightarrow $ [File] $ \rightarrow $ [Export active sheet]). After selecting a file path, a file name and one of the file types on the Windows save-as dialog, the data on the active worksheet will be exported into the file.

NOTE: If the file type is text, the file is written in the character encoding set specified on the [System environment] form. The character encoding of the file can be changed from the menu [Parcel Maker] $ \rightarrow $ [Settings] $ \rightarrow $ [set environment].

## 11.1.2. Exporting a dictionary into separate files

ParcelMaker has another function to export ontological elements into separate files by one action. The function is called through a submenu of ParcelMaker (i.e. [Parcel Maker] $ \rightarrow $ [File] $ \rightarrow $ [Export sheets of dictionary]). Supported file types are text (".csv", ".txt" and ".pcl") and Excel book (".xls" and ".xlsx").

The function is available only if one of dictionary sheets is active. After selecting a file path, a BASE file name and one of the file types on the Windows save-as dialog, ontological elements will be exported into their corresponding files (e.g., if a base file name is "CDD" and ".csv" is selected as its file type, a class is exported to the "CDD_CLASS.csv" file and a property is exported to the "CDD_PROPERTY.csv" file.)

NOTE: If the file type is text, the file is written in the character encoding set specified on the [System environment] form. The character encoding of the file can be changed from the menu [Parcel Maker] $ \rightarrow $ [Settings] $ \rightarrow $ [set environment].

## 11.2. Import

## 11.2.1. Importing data from files into the active sheet

ParcelMaker has a function to import data from other files into the active worksheet. Supported file types are text (".csv", ".txt" and ".pcl") and Excel book (".xls" and ".xlsx") and files with different extensions are selectable at the same time. The function automatically

sets the values for properties into their corresponding columns in the worksheet. Thus, there is no need to worry about the difference between the order of the columns in the worksheet and that of the columns in the files.

The function is available only for dictionary sheets, instance data sheets and instance data generation sheets. It is called through a submenu of ParcelMaker (i.e. [Parcel Maker] $ \rightarrow $ [File] $ \rightarrow $ [Import from file ...]). After selecting files in the Windows file-open dialog, the data in the files will be imported into the active worksheet.

NOTE: If a file is text, the data in the file is read in the character encoding set specified on the [System environment] form. If imported data is garbled, either change the character encoding of the file or change the encoding setting using a menu [Parcel Maker] $ \rightarrow $ [Settings] $ \rightarrow $ [set environment].

## 11.2.2. Importing data from another sheet into the active sheet

There is a function to read data from another sheet on the same workbook into the active worksheet of the workbook. Just like the function described in the subsection 11.2.1, this function also handles differences in the order of the properties between the two sheets.

The function is available under the same condition described in the subsection 11.2.1, and is called through a submenu of ParcelMaker (i.e. [Parcel Maker] $ \rightarrow $ [File] $ \rightarrow $ [Import from another sheet]). The selectable sheets in a workbook are listed in the form shown as in Figure 32. After double-clicking on one of the sheets, the data on the selected sheet will be imported into the active worksheet. Here, in contrast to the function described in the subsection 11.2.1, the type of meta-data from importable sheets is limited to the same type of meta-data in the active worksheet.

To show an example of sheet import, in Figure 32 where there are 3 dictionaries (i.e. IEC61360, IEC_SC65E and ECALSv9_1) and the class sheet of the ECALSv9_1 dictionary is active, only the class sheets of the other 2 dictionaries, i.e. IEC61360 and IEC_SC65E, are selectable on the form. Figure 33 shows an example of the result of importing data from the class sheet of the IEC_SC65E dictionary into the class sheet of the ECALSv9_1 dictionary.

![](page=42,bbox=[477, 353, 1502, 1261])

<div align="center">

Figure 32: How to import data from another sheet

</div>

![](page=42,bbox=[473, 1431, 1633, 2351])

<div align="center">

Figure 33: Example of import class data from the class sheet of the SC65E dictionary

</div>

## 12. Set up

## 12.1. Setting the visibility of an item in a header section

The visibility of each item in a header section is controllable by means of the form loaded from the menu [Parcel Maker] $ \rightarrow $ [settings] $ \rightarrow $ [Header visibility] (Figure 34). On this form, checked items are set visible, and unchecked items are set hidden. The setting will be applied to all parcel sheets in a workbook.

There are two frames on the form, one is for class header section and the other is for schema header section. To press [Select All]/[Deselect All] buttons in each frame will make all items in the same frame checked/unchecked. To press [Default] button will provide a recommended and common setting for many users.

<div align="center">

NOTE: The visibility of "CLASS_ID" and "PROPERTY ID" is not changeable because they are mandatory.

</div>

![](page=43,bbox=[621, 1253, 1368, 2345])

<div align="center">

Figure 34: Controlling the visibility of a header item

</div>

## 12.2. Enable/disable ParcelMaker functions

ParcelMaker gives various functions, such as special forms, real-time validation. Although those functions usually help users, but sometimes they may interfere for users. For the latter case, ParcelMaker provides three options in the menu [ParcelMaker] $ \rightarrow $ [Settings] which enable/disable the following functions shown as in Figure 35.

- Double-click action: if this option is not checked, any form will not be shown when double-clicking a cell.

- Colouring erroneous cell: if this option is not checked, the real-time validation function described in subclause 8.1 does not work.

- Colouring comment line: if this option is not checked, the comment line is not coloured in green as described in subclause 6.2.

<table class="table table-bordered"><thead><tr><th>A</th><th>B</th><th>C</th><th>D</th><th>E</th></tr></thead><tbody><tr><td colspan="6">Dictionary</td></tr><tr><td colspan="6">Import from</td></tr><tr><td colspan="6">Export</td></tr><tr><td colspan="6">Generate instance</td></tr><tr><td colspan="6">Tools</td></tr><tr><td>12</td><td>#PROPE</td><td>MDC_P001</td><td>MDC_P002</td><td>MDC_P002</td><td>MDC_P002</td></tr><tr><td>14</td><td>#PROPE</td><td>Code</td><td>Version nu</td><td>Revision nu</td><td>Date o</td></tr><tr><td>15</td><td>#DEFINIT</td><td>globally un</td><td>version of a</td><td>revision of a</td><td>date w</td></tr><tr><td>16</td><td>#NOTE e</td><td>The value r</td><td>The version</td><td>Revision s</td><td>The value s</td></tr><tr><td>17</td><td>#DATATY</td><td>STRING_T</td><td>STRING_T</td><td>STRING_T</td><td>STRING_T</td></tr><tr><td>18</td><td>#UNIT</td><td></td><td></td><td></td><td></td></tr><tr><td>22</td><td>#VALUE</td><td>M..255</td><td>M..10</td><td>M..3</td><td>M..10</td></tr><tr><td>24</td><td>#DEFAULT</td><td>0112/2///61360_4</td><td></td><td></td><td></td></tr><tr><td>25</td><td>#DEFAULT</td><td>1</td><td></td><td></td><td></td></tr><tr><td>26</td><td>#PATTERN</td><td></td><td></td><td></td><td></td></tr><tr><td>27</td><td>#REQUIR</td><td>KEY</td><td>MAND</td><td>MAND</td><td>MAND</td></tr><tr><td>28</td><td></td><td>AAD001</td><td>001</td><td>02</td><td>2005-03-31 2005-03-31</td></tr><tr><td>29</td><td></td><td>AAD002</td><td>001</td><td>01</td><td>2005-03-31 2005-03-31</td></tr><tr><td>30</td><td></td><td>AAD003</td><td>001</td><td>01</td><td>2005-03-31 2005-03-31</td></tr><tr><td>31</td><td></td><td>AAD004</td><td>001</td><td>01</td><td>2005-03-31 2005-03-31</td></tr><tr><td>32</td><td></td><td>AAD005</td><td>001</td><td>01</td><td>2005-03-31 2005-03-31</td></tr><tr><td>33</td><td></td><td>AAD006</td><td>001</td><td>02</td><td>2005-03-31 2005-03-31</td></tr><tr><td>34</td><td></td><td>AAD007</td><td>001</td><td>01</td><td>2005-03-31 2005-03-31</td></tr><tr><td>35</td><td></td><td>AAD008</td><td>001</td><td>01</td><td>2005-03-31 2005-03-31</td></tr></tbody></table>

<div align="center">

Figure 35: Options to enable/disable ParcelMaker functions

</div>

## 12.3. How to change a language for displaying data

The language used for displaying multilingual values of properties displayed on the forms of ParcelMaker can be changed through a submenu of ParcelMaker (i.e. [Parcel Maker] $ \rightarrow $ [Settings] $ \rightarrow $ [Data language]). In the current version of ParcelMaker, 8 languages (i.e. English, French and Japanese) are supported. If there is no value for the specified language, a value for the base language set up through the steps described in the subsection 12.4 is displayed.

## 12.4. How to specify languages to be translated

The languages used for editing multilingual values of properties whose data type is "TRANSLATED_STRING_TYPE" can be set through a submenu of ParcelMaker (i.e. [Parcel Maker]-[Settings]-[Multi language]) shown as inFigure 36. The setting in a workbook is available to all sheets in the workbook. After selecting the submenu, the [Multi language] form will be displayed.

The operation on the form is the same as is described in the section 1.1. [**** section 6.1 does NOT describe the multi language function *****]

On the form, the left hand side list box shows a list of languages you can use, and the right hand side list box shows a list of languages you currently use for language dependent values of translatable properties in an added dictionary. The Source language combo box is used for setting the base language of the added dictionary.

![](page=45,bbox=[501, 1716, 1483, 2301])

<div align="center">

Figure 36: Setting of used languages

</div>

## 12.5. How to set up a system environment

The last submenu for the settings is for the general settings for a workbook, and is not normally changed. The menu is available through the submenu of ParcelMaker (i.e. [Parcel Maker]-[Settings]-[Environment]).

After selecting the submenu, the [Set Environment] shown as in Figure 37 will be displayed. First of all, the item [Operation language] is used to set the language for messages, menu items and labels on forms. Next, the item [Encoding] is used for the character encoding for input/output of CSV files.

![](page=46,bbox=[649, 945, 1334, 1333])

<div align="center">

Figure 37: Setting of a system environment

</div>

## 13. Advanced functions

## 13.1. View control

ParcelMaker gives each dictionary an extra sheet for "View control meta-class" which describes view information for each meta-class sheet. View control meta-class has two meta-properties for defining view information; one is a meta-property "Controlled classes" identified with EXT_P002 to specify classes to be controlled, and the other is a meta-property "Shown properties" identified with EXT_P003 to list properties to be shown for classes described in the meta-property EXT_P002.

Properties listed in EXT_P003 are editable on a form shown as in which will be loaded by double-clicking on a cell in a cell column with the meta-property EXT_P002. In this figure, Properties listed in the field on the top of the form are properties to be shown in order, while properties listed in the field on the bottom of the form are properties to be hidden. The [Add]/[Delete] button allows adding/deleting properties to/from the properties listed in the field on the top of the form. The order of properties listed in the field on the top of the form can be changed with the [Up]/[Down] button. After pressing the [OK] button, a well-formed value will be entered into the cell.

![](page=48,bbox=[614, 333, 1371, 1410])

<div align="center">

Figure 38: GUI for Setting up shown properties

</div>

View control can be applied to an active worksheet via the menu [Parcel Maker] $ \rightarrow $ [Tools] $ \rightarrow $ [View control]. When select the menu, a GUI shown as in will be loaded. In this form, view candidates for the worksheet will be displayed. After selecting a view from the combo box on the top of the form and pressing the [OK] button, cell columns of the workbook will be reconfigured complying with the selected view.

![](page=49,bbox=[660, 351, 1328, 1022])

<div align="center">

Figure 39: GUI for applying view control

</div>

## 14. Error log

A critical error occurred while working on ParcelMaker will be recorded as an error log. A log file is placed on the [Log] folder, where can be accessed through the shortcut [Log]. A log file is generated daily, but if there are no errors in a day, an empty file will be automatically deleted.

If you encounter an error or a problem, please contact either with an error log.

akira.hosokawa@toshiba.co.jp

hiroshi.murayama@toshiba.co.jp

## 15. COPYRIGHT AND LICENSE AGREEMENT

<table><tr><td>July 2013</td></tr><tr><td>System Engineering Laboratory, Corporate Research &amp; Development Center, Toshiba Corporation</td></tr><tr><td>1, Komukai Toshiba-cho, Saiwai-ku, Kawasaki-shi, 212-8582, JAPAN</td></tr><tr><td>Toshiba Corporation (hereafter, Toshiba) grants you (hereafter, Licensee) to use the IEC62656-1 CDV spreadsheet "ParcelMaker" (hereafter, the Software) under the following conditions:</td></tr><tr><td>1. Definition.</td></tr><tr><td>The Software includes the following components from (1) to (3).</td></tr><tr><td>(1) add-in</td></tr><tr><td>(2) documents</td></tr><tr><td>(3) any data files and text files included in the distributed package</td></tr><tr><td>The term "distribution" includes any style of distribution: electronically, via computer networks, by means of storage media like a floppy disk, and so on.</td></tr><tr><td>2. Title to the Software.</td></tr><tr><td>Toshiba is and shall remain the sole and exclusive owner of the Software and the copies thereof.</td></tr><tr><td>3. Purpose of Use and Restrictions.</td></tr><tr><td>Toshiba grants to Licensee a non-exclusive license to download, use, and make multiple copies of the Software solely for disseminating IEC62656-1 CDV standard purposes only. The Software shall be used as it is and Licensee may not make any modification of the Software. Licensee may not decompile, disassemble, or reverse engineer the byte codes</td></tr></table>

<table><tr><td>4. Redistribution.</td></tr><tr><td>Licensee may not reproduce the Software on any media or redistribute the Software to any network. All who wish to use the Software shall agree with the license agreement and obtain the Software directly from Toshiba.</td></tr><tr><td>5. Gratuitousness.</td></tr><tr><td>The Licensee may use this Software of the version, distributed by and obtained from Toshiba directly, free of charge for the individual use of the Licensee. The Software shall not be sold or redistributed by any other party without a written permission from Toshiba. Toshiba retains the right to distribute an updated version of this Software with a charge in future. Licensee shall agree this prior to download and use the Software granted by Toshiba with this license agreement.</td></tr><tr><td>6. Exemption.</td></tr><tr><td>THIS SOFTWARE IS DISTRIBUTED AS IS. TOSHIBA DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL TOSHIBA BE LIABLE FOR ANY DAMAGES, INCLUDING SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE, MODIFICATION, DISTRIBUTION, OR PERFORMANCE OF THIS SOFTWARE OR ITS DERIVATIVE WORKS.</td></tr><tr><td>7. Export Restrictions.</td></tr><tr><td>By downloading the Software, Licensee agrees that the Software and any underlying technical information is intended to or will be exported directly or indirectly to any destination restricted or prohibited by Japanese and other applicable export control laws and regulations.</td></tr></table>

8. Termination.

Toshiba may terminate this agreement upon Licensee's breach of this agreement and Licensee shall immediately delete the Software provided by Toshiba and its copies.
