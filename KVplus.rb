class Plugin
	@classes = Hash.new
	def self.classes ; return @classes ; end
	def self.inherited(subclass)
		puts "PLUGIN: " + subclass.to_s
		self.classes[subclass.to_s] = subclass
	end
end

def parseKV(fileName)
	kv = Hash.new
	stack = Array.new

	file = File.read(fileName)
	#puts("encoding: " + file.encoding.to_s)

	#puts Encoding.name_list.to_s
	#encoding detection
	if file["\x00L\x00a\x00n\x00g\x00u\x00a\x00g\x00e\x00"]
		#puts("UCS2")
		#puts file
		file = File.open(fileName, "rb:utf-16").read.encode(Encoding::UTF_8, Encoding::UTF_16)
		#puts file
	end

	file = file.gsub(/\/\/.*/, "") # dump comments
	file = file.gsub(/{/, "\r\n{\r\n") # put { on own line
	file = file.gsub(/}/, "\r\n}\r\n") # put } on own line
	file = file.gsub(/^\s*\r?\n/, "") #dump empty lines

	i = 0
	curToken = nil
	foundFirst = false

	file.lines.each{|line|
		line = line.gsub(/""/, '" "') # separate quoted tokens

		#tokens = line.split
		qcount = line.scan(/"/).count - line.scan(/\\"/).count 
		if qcount % 2 != 0
			line = line + '"'
		end
		tokens = line.scan( /([^"\s]+)|"([^"]+)"/ ).flatten.compact
		tokens2 = Array.new
		tokens.each{|token|
			token = token.gsub('\"', "$$@$$")
			token = token.gsub('"', "")
			token = token.gsub("$$@$$", '"')
			tokens2.push(token)

			if !foundFirst and token[/{/]
				foundFirst = true
				next
			elsif !foundFirst
				next
			end



			if token[/{/]
				newKv = Hash.new
				arr = kv[curToken]
				if arr == nil then
					arr = Array.new
					kv[curToken] = arr
				end
				arr.push(newKv)
				stack.push(kv)
				kv = newKv
				curToken = nil
			elsif token[/}/]
				curToken = nil
				prekv = stack.pop()
				if prekv != nil 
					kv = prekv
				end
			elsif curToken == nil
				curToken = token
			else
				arr = kv[curToken]
				if arr == nil then
					arr = Array.new
					kv[curToken] = arr
				end
				arr.push(token)
				curToken = nil
			end
		}
		#puts i.to_s + "-- " + tokens2.join(', ')  + ''
		#puts i.to_s + "-- {" + kv.to_s + "}"
		i+=1
	}

	return kv
end

def writeKV_UCS2(file, first, kv)
	file = File.open(file, "w:UTF-16LE")
	file.write "\uFEFF"
	file.write first + "\n"
	_writeKV(file, kv, 0)
end

def writeKV(file, first, kv)
	if file.instance_of? File
		file.write first + "\n"
		_writeKV(file, kv, 0)
	else
		file = File.open(file, "w:UTF-8")
		file.write first + "\n"
		_writeKV(file, kv, 0)
	end
end

def _writeKV(file, kv, depth)
	file.write "\t" * depth  + "{" + "\n"
	kv.each{|k,v|
		v.each{|val|
			if val.instance_of? String
				file.write "\t" * (depth+1) + '"' + k + '"    "' + val + '"' + "\n"
			else
				file.write "\t" * (depth+1) + '"' + k + '"' + "\n"
				_writeKV(file, val, depth+1)
			end
		}
	}
	file.write "\t" * depth  + "}" + "\n"
end

def printKV(kv)
	_prinKV(kv, 0)
end

def _printKV(kv, depth)
	puts "\t" * depth  + "{"
	kv.each{|k,v|
		v.each{|val|
			if val.instance_of? String
				puts "\t" * (depth+1) + '"' + k + '"    "' + val + '"'
			else
				puts "\t" * (depth+1) + '"' + k + '"'
				_printKV(val, depth+1)
			end
		}
	}
	puts "\t" * depth  + "}"
end

optFile = "KVplus.kv"
if ARGV.count > 0
	optFile = ARGV[1]
end

options = parseKV(optFile)

kvs = Hash.new
options["Input"].each{|input|
	if File.directory?(input)
		Dir.glob(input + "/*.txt") do |file|
			name = File.basename(file)
			if kvs[name] != nil
				puts "WARNING: Duplicate named Input -- " + name
			end
			kvs[name] = parseKV(file)
		end
		Dir.glob(input + "/*.kv") do |file|
			name = File.basename(file)
			if kvs[name] != nil
				puts "WARNING: Duplicate named Input -- " + name
			end
			kvs[name] = parseKV(file)
		end
	else
		name = File.basename(input)
		if kvs[name] != nil
			puts "WARNING: Duplicate named Input -- " + name
		end
		kvs[name] = parseKV(input)
	end
}

options["Plugins"][0].each{|k,v|
	require_relative ("plugins/" + k)

	plugin = Plugin.classes[k].new
	if plugin.respond_to? :init
		plugin.init
	end
	plugin.execute(kvs, v)
}
