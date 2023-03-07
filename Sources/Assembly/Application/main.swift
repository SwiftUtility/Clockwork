import Foundation
import Facility
import InteractivityCommon
SideEffects.reportMayDay = { mayDay in FileHandle.standardError.write(message: """
  ⚠️⚠️⚠️
  Please submit an issue at https://github.com/SwiftUtility/Clockwork/issues/new/choose
  Version: \(Clockwork.version)
  What: \(mayDay.what)
  File: \(mayDay.file)
  Line: \(mayDay.line)
  ⚠️⚠️⚠️
  """
)}
SideEffects.printDebug = FileHandle.standardError.write(message:)
Clockwork.main()
