# PhonecallOrg

This program will convert the backup files from [Call Logs Backup & Restore](https://play.google.com/store/apps/details?id=com.riteshsahu.CallLogBackupRestore) to org-mode files.

# Example Call Log

```xml
<?xml version='1.0' encoding='UTF-8' standalone='yes' ?><?xml-stylesheet type="text/xsl" href="calls.xsl"?>
<calls count="8">
  <call number="+4388812345678" duration="0" date="1303378237194" type="3" readable_date="2011/21/04 11:30:37" contact_name="Peter Foobar" />
  <call number="+4388812345678" duration="55" date="1303378253988" type="2" readable_date="2011/21/04 11:30:53" contact_name="Peter Foobar" />
</xml>
```

# Example output of phonecallOrg

```org-mode
* <2014-10-18 Sat 08:29:10>--<2014-10-18 Sat 08:30:53> call from [[contact:Max Muster][Max Muster]]
  :PROPERTIES:
  :DURATION: 103s
  :PHONE:    +436651234567
```

# Example invocation

This call will read all entries from calls.xml and write only those which are newer than the entries from the last import.

: phonecallOrg --inputfile=/mnt/phone/calls.xml --outputfile=/home/odi/Phone.org

If you would like to import all entries even if there are entries from the last one.

: phonecallOrg -c --inputfile=/mnt/phone/calls.xml --outputfile=/home/odi/Phone.org