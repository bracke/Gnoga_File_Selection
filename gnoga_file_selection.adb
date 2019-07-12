with Ada.Containers.Indefinite_Ordered_Sets;
with Ada.Directories;
with Gnoga.Gui.Base;
with Gnoga.Gui.Modal_Dialog;
with Gnoga.Gui.Element.Common;
with Gnoga.Gui.Element.Form;
with Gnoga.Gui.View;

package body Gnoga_File_Selection is
   function Select_File (Window : in out Gnoga.Gui.Window.Window_Type'Class; Initial_Directory : in String := ".")
   return Result_Info is
      Directory_Tag : constant String := " (directory)";

      package Name_Lists is new Ada.Containers.Indefinite_Ordered_Sets (Element_Type => String);

      use Ada.Strings.Unbounded;

      protected Control is
         entry Wait_Until_Changed;
         procedure Signal_Changed;
      private -- Control
         Changed : Boolean := False;
      end Control;

      procedure Up_Clicked (Object : in out Gnoga.Gui.Base.Base_Type'Class);
      -- Change current directory to parent of current directory

      procedure File_Selected (Object : in out Gnoga.Gui.Base.Base_Type'Class);
      -- User clicked on a file in the file list

      procedure Cancel_Clicked (Object : in out Gnoga.Gui.Base.Base_Type'Class);
      -- User clicked on Cancel; return nothing picked

      procedure OK_Clicked (Object : in out Gnoga.Gui.Base.Base_Type'Class);
      -- User clicked on OK; return selected or entered file name

      procedure Fill_List (Directory : in String; List : in out Gnoga.Gui.Element.Form.Selection_Type);
      -- Clears List, then adds the files in Directory to it, directories first, in alphabetical order

      Result_Ready : Boolean := False with Atomic;
      Result       : Result_Info;
      Current_Dir  : Unbounded_String := To_Unbounded_String (Ada.Directories.Full_Name (Initial_Directory) );
      File_List    : Gnoga.Gui.Element.Form.Selection_Type;
      File_Input   : Gnoga.Gui.Element.Form.Text_Type;

      protected body Control is
         entry Wait_Until_Changed when Changed is
            -- Empty
         begin -- Wait_Until_Changed
            Changed := False;
         end Wait_Until_Changed;

         procedure Signal_Changed is
            -- Empty
         begin -- Signal_Changed
            Changed := True;
         end Signal_Changed;
      end Control;

      procedure Up_Clicked (Object : in out Gnoga.Gui.Base.Base_Type'Class) is
         -- Empty
      begin -- Up_Clicked
         Current_Dir := To_Unbounded_String (Ada.Directories.Containing_Directory (To_String (Current_Dir) ) );
         Control.Signal_Changed;
      end Up_Clicked;

      procedure File_Selected (Object : in out Gnoga.Gui.Base.Base_Type'Class) is
         Index : constant Natural := File_List.Selected_Index;
      begin -- File_Selected
         if Index = 0 then
            return;
         end if;

         Get_Name : declare
            Name : constant String := File_List.Value (Index);
         begin -- Get_Name
            if Name'Length <= Directory_Tag'Length or else Name (Name'Last - Directory_Tag'Length + 1 .. Name'Last) /= Directory_Tag
            then -- Normal file
               File_Input.Value (Value => Name);
            else -- Directory
               Current_Dir := To_Unbounded_String (Ada.Directories.Compose (To_String (Current_Dir),
                                                   Name (Name'First .. Name'Last - Directory_Tag'Length) ) );
               File_Input.Value (Value => "");
               Control.Signal_Changed;
            end if;
         end Get_Name;
      end File_Selected;

      procedure Cancel_Clicked (Object : in out Gnoga.Gui.Base.Base_Type'Class) is
         -- Empty
      begin -- Cancel_Clicked
         Result_Ready := True;
         Control.Signal_Changed;
      end Cancel_Clicked;

      procedure OK_Clicked (Object : in out Gnoga.Gui.Base.Base_Type'Class) is
         Name : constant String := File_Input.Value;
      begin -- OK_Clicked
         if Name /= "" then
            Result := (Picked => True, Value => To_Unbounded_String (Ada.Directories.Compose (To_String (Current_Dir), Name) ) );
            Result_Ready := True;
            Control.Signal_Changed;
         end if;
         -- else ignore
      end OK_Clicked;

      procedure Fill_List (Directory : in String; List : in out Gnoga.Gui.Element.Form.Selection_Type) is
         procedure Clear (List : in out Gnoga.Gui.Element.Form.Selection_Type);
         -- Removes all options from List

         procedure Add_Dir (Position : in Name_Lists.Cursor);
         -- Adds the Name at Position to List with Directory_Tag added to the end

         procedure Add_File (Position : in Name_Lists.Cursor);
         -- Adds the name at Position to List

         procedure Clear (List : in out Gnoga.Gui.Element.Form.Selection_Type) is
         -- Empty
         begin -- Clear
            All_Options : for I in reverse 1 .. List.Length loop
               List.Remove_Option (Index => I);
            end loop All_Options;
         end Clear;

         procedure Add_Dir (Position : in Name_Lists.Cursor) is
            Name : constant String := Name_Lists.Element (Position) & Directory_Tag;
         begin -- Add_Dir
            List.Add_Option (Value => Name, Text => Name);
         end Add_Dir;

         procedure Add_File (Position : in Name_Lists.Cursor) is
            Name : constant String := Name_Lists.Element (Position);
         begin -- Add_File
            List.Add_Option (Value => Name, Text => Name);
         end Add_File;

         Search_Info : Ada.Directories.Search_Type;
         File_Info   : Ada.Directories.Directory_Entry_Type;
         Dir_List    : Name_Lists.Set;
         File_List   : Name_Lists.Set;
      begin -- Fill_List
         Clear (List => List);
         Ada.Directories.Start_Search (Search    => Search_Info,
                                       Directory => Directory,
                                       Pattern   => "*",
                                       Filter    => (Ada.Directories.Special_File => False, others => True) );

         All_Entries : loop
            exit All_Entries when not Ada.Directories.More_Entries (Search_Info);

            Ada.Directories.Get_Next_Entry (Search => Search_Info, Directory_Entry => File_Info);

            case Ada.Directories.Kind (File_Info) is
            when Ada.Directories.Directory =>
               Get_Name : declare
                  Name : constant String := Ada.Directories.Simple_Name (File_Info);
               begin -- Get_Name
                  if Name /= "." and Name /= ".." then
                     Dir_List.Insert  (New_Item => Name);
                  end if;
               end Get_Name;
            when Ada.Directories.Ordinary_File =>
               File_List.Insert  (New_Item => Ada.Directories.Simple_Name (File_Info) );
            when Ada.Directories.Special_File =>
               null;
            end case;
         end loop All_Entries;

         Dir_List.Iterate (Process => Add_Dir'Access);
         File_List.Iterate (Process => Add_File'Access);
      end Fill_List;

      Dialog   : Gnoga.Gui.Modal_Dialog.Dialog_Type;
      View     : Gnoga.Gui.View.View_Type;
      Form     : Gnoga.Gui.Element.Form.Form_Type;
      Dir_Line : Gnoga.Gui.Element.Form.Text_Type;
      Up       : Gnoga.Gui.Element.Common.Button_Type;
      Cancel   : Gnoga.Gui.Element.Common.Button_Type;
      OK       : Gnoga.Gui.Element.Common.Button_Type;
   begin -- Select_File
      Dialog.Create (Parent => Window);
      Dialog.Create_Main_View (View => View);
      Form.Create (Parent => View);
      Dir_Line.Create (Form => Form, Size => 100);
      Dir_Line.Read_Only;
      Up.Create (Parent => Form, Content => "Up");
      Up.On_Click_Handler (Handler => Up_Clicked'Unrestricted_Access);
      Form.New_Line;
      File_List.Create (Form => Form, Visible_Lines => 20);
      File_List.On_Click_Handler (Handler => File_Selected'Unrestricted_Access);
      Form.New_Line;
      File_Input.Create (Form => Form, Size => 50);
      Cancel.Create (Parent => Form, Content => "Cancel");
      Cancel.On_Click_Handler (Handler => Cancel_Clicked'Unrestricted_Access);
      OK.Create (Parent => Form, Content => "OK");
      OK.On_Click_Handler (Handler => OK_Clicked'Unrestricted_Access);
      Dialog.Show;

      All_Dirs : loop
         Dir_Line.Value (Value => To_String (Current_Dir) );
         File_Input.Value (Value => "");
         Fill_List (Directory => To_String (Current_Dir), List => File_List);
         Control.Wait_Until_Changed;

         if Result_Ready then
            Dialog.Remove;

            return Result;
         end if;
      end loop All_Dirs;
   end Select_File;
end Gnoga_File_Selection;
