class ExamplePlugin < Plugin
	def init()
		puts "EXAMPLEPLUGIN"
	end

	def execute(kvs, options)
		puts "EXAMPLEPLUGIN: execute"
		puts options.to_s
		puts writeKV_UCS2("out.txt", "lang", kvs["addon_english.txt"])
	end
end