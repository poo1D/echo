require "securerandom"

pbxproj = "/Users/lidengye/Desktop/EchoPKM/EchoPKM.xcodeproj/project.pbxproj"
content = File.read(pbxproj)

new_files = [
  { name: "HealthSnapshot.swift", path: "EchoPKM/Models/HealthSnapshot.swift", group: "Models" },
  { name: "HealthKitService.swift", path: "EchoPKM/Services/HealthKitService.swift", group: "Services" },
  { name: "IntentRouter.swift", path: "EchoPKM/Services/IntentRouter.swift", group: "Services" },
  { name: "CorrelationEngine.swift", path: "EchoPKM/Services/CorrelationEngine.swift", group: "Services" },
  { name: "MoodAtmosphere.swift", path: "EchoPKM/Helpers/MoodAtmosphere.swift", group: "Helpers" },
  { name: "EchoPKM.entitlements", path: "EchoPKM/EchoPKM.entitlements", group: "EchoPKM" },
]

def gen_id
  SecureRandom.hex(12).upcase
end

file_refs = []
build_files = []

new_files.each do |f|
  file_ref_id = gen_id
  build_file_id = gen_id

  is_entitlements = f[:name].end_with?(".entitlements")

  file_refs << { id: file_ref_id, name: f[:name], path: f[:path], group: f[:group] }
  unless is_entitlements
    build_files << { id: build_file_id, file_ref_id: file_ref_id, name: f[:name] }
  end
end

# Add PBXFileReference entries
marker = "/* Begin PBXFileReference section */"
entries = file_refs.map { |f|
  if f[:name].end_with?(".entitlements")
    "\t\t#{f[:id]} /* #{f[:name]} */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = #{f[:name]}; sourceTree = \"<group>\"; };"
  else
    "\t\t#{f[:id]} /* #{f[:name]} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = #{f[:name]}; sourceTree = \"<group>\"; };"
  end
}.join("\n")
content = content.sub(marker, marker + "\n" + entries)

# Add PBXBuildFile entries
marker2 = "/* Begin PBXBuildFile section */"
bf_entries = build_files.map { |f|
  "\t\t#{f[:id]} /* #{f[:name]} in Sources */ = {isa = PBXBuildFile; fileRef = #{f[:file_ref_id]} /* #{f[:name]} */; };"
}.join("\n")
content = content.sub(marker2, marker2 + "\n" + bf_entries)

# Add to PBXSourcesBuildPhase
sources_re = /(\/\* Begin PBXSourcesBuildPhase section \*\/.*?files = \(\n)(.*?)(\t\t\t\);)/m
if content =~ sources_re
  prefix = $1
  existing = $2
  suffix = $3
  new_entries = build_files.map { |f|
    "\t\t\t\t#{f[:id]} /* #{f[:name]} in Sources */,"
  }.join("\n") + "\n"
  content = content.sub(sources_re, prefix + existing + new_entries + suffix)
end

# Add file references to groups
file_refs.each do |f|
  group_name = f[:group]
  group_re = /(\/\* #{Regexp.escape(group_name)} \*\/ = \{[^}]*children = \(\n)(.*?)(\t\t\t\);)/m
  if content =~ group_re
    prefix = $1
    existing = $2
    suffix = $3
    new_child = "\t\t\t\t#{f[:id]} /* #{f[:name]} */,\n"
    content = content.sub(group_re, prefix + existing + new_child + suffix)
  else
    puts "WARNING: Could not find group '#{group_name}' in pbxproj"
  end
end

# Add HealthKit framework
hk_ref_id = gen_id
hk_bf_id = gen_id

# Framework file reference
fr_marker = "/* Begin PBXFileReference section */"
hk_ref = "\t\t#{hk_ref_id} /* HealthKit.framework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = HealthKit.framework; path = System/Library/Frameworks/HealthKit.framework; sourceTree = SDKROOT; };"
content = content.sub(fr_marker, fr_marker + "\n" + hk_ref)

# Framework build file
bf_marker = "/* Begin PBXBuildFile section */"
hk_bf = "\t\t#{hk_bf_id} /* HealthKit.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = #{hk_ref_id} /* HealthKit.framework */; };"
content = content.sub(bf_marker, bf_marker + "\n" + hk_bf)

# Add to Frameworks build phase
fw_re = /(\/\* Begin PBXFrameworksBuildPhase section \*\/.*?files = \(\n)(.*?)(\t\t\t\);)/m
if content =~ fw_re
  prefix = $1
  existing = $2
  suffix = $3
  new_entry = "\t\t\t\t#{hk_bf_id} /* HealthKit.framework in Frameworks */,\n"
  content = content.sub(fw_re, prefix + existing + new_entry + suffix)
end

File.write(pbxproj, content)
puts "Done! Added #{new_files.length} files + HealthKit framework"
file_refs.each { |f| puts "  #{f[:id]} -> #{f[:name]}" }
build_files.each { |f| puts "  #{f[:id]} -> #{f[:name]} (build)" }
puts "  #{hk_ref_id} -> HealthKit.framework"
puts "  #{hk_bf_id} -> HealthKit.framework (build)"
