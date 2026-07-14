-- Minimal test harness for running npcsystem tests under plain lua5.1.
Test = {
	passed = 0,
	failed = 0,
	failures = {}
}

function Test.case(name, fn)
	local ok, err = pcall(fn)
	if(ok) then
		Test.passed = Test.passed + 1
	else
		Test.failed = Test.failed + 1
		table.insert(Test.failures, name .. '\n    ' .. tostring(err))
	end
end

function assert_eq(actual, expected, what)
	if(actual ~= expected) then
		error((what or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2)
	end
end

function assert_true(value, what)
	if(not value) then
		error((what or 'condition') .. ': expected true, got ' .. tostring(value), 2)
	end
end

function assert_nil(value, what)
	if(value ~= nil) then
		error((what or 'value') .. ': expected nil, got ' .. tostring(value), 2)
	end
end

function Test.summary()
	print(string.format('%d passed, %d failed', Test.passed, Test.failed))
	if(Test.failed > 0) then
		print('')
		print('FAILURES:')
		for _, failure in ipairs(Test.failures) do
			print('  - ' .. failure)
		end
		os.exit(1)
	end
end
