with Ada.Strings.Unbounded;
with Gnoga.Gui.Window;

package Gnoga_File_Selection is
   type Result_Info (Picked : Boolean := False) is record
      case Picked is
      when False =>
         null;
      when True =>
         Value : Ada.Strings.Unbounded.Unbounded_String;
      end case;
   end record;

   function Select_File (Window : in out Gnoga.Gui.Window.Window_Type'Class; Initial_Directory : in String := ".")
   return Result_Info;
   -- Opens a file-selection dialog for Window with the files for Initial_Directory
   -- If the user cancels the dialog, returns (Picked => False)
   -- Otherwise, the return value has Picked => True and the Value component contains the full path of the selected file
   -- Note that this selects files on the computer the program is running on, not the computer the browser is running on
end Gnoga_File_Selection;
