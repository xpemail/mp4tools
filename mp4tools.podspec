Pod::Spec.new do |s|
s.name = "mp4tools"
s.version = "1.0.0"
s.summary = "mp4截取"
s.homepage = "https://github.com/xpemail/mp4tools"
s.license = "MIT"
s.author = { "wuxiande" => "wuxiande@soooner.com" }
s.ios.deployment_target = "6.0"
s.source = { :git => 'https://github.com/xpemail/mp4tools.git', :tag => '1.0.0' }
s.requires_arc = true
s.source_files = '*.{h,m,mm,pch}'
end
