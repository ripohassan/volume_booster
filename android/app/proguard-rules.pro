# Backport file_picker's upstream fix for the Tika 3.2.0 StAX reference.
# file_picker 10.3.3 already handles XMLInputFactory/XMLResolver in its consumer
# rules but omits this exception type. Keep R8 and all other diagnostics enabled.
# https://github.com/vicajilau/flutter_file_picker/pull/1968
-dontwarn javax.xml.stream.XMLStreamException
