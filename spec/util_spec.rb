
require 'spec_helper'
require 'asa_console/util'

RSpec.describe ASAConsole::Util do

  context '::apply_control_chars' do
    it 'can apply backspace characters' do
      input = "hello world\b\b\b\b\bW\b\b\b\b\b\b\bH\n"
      output = ASAConsole::Util.apply_control_chars(input)
      expect(output).to eq "Hello World\n"
    end
    it 'can apply carriage returns' do
      input = "Hello\rGoodbye\r\nworld\rW\r\n"
      output = ASAConsole::Util.apply_control_chars(input)
      expect(output).to eq "Goodbye\nWorld\n"
    end
  end

  context '::parse_cisco_time' do

    str = '16:04:31.458 PDT Thu Aug 6 2015'
    context "result from parsing #{str.dump}" do
      time = ASAConsole::Util.parse_cisco_time(str)
      it 'is a Time object' do
        expect(time).to be_a Time
      end
      it 'has the correct year, month and day' do
        expect(time.year).to eq 2015
        expect(time.month).to eq 8
        expect(time.day).to eq 6
      end
      it 'has the correct hour, minute and second' do
        expect(time.hour).to eq 16
        expect(time.min).to eq 4
        expect(time.sec).to eq 31
      end
      it 'has the correct subseconds' do
        expect(time.subsec).to eq 0.458
      end
      it 'is a Thursday' do
        expect(time.thursday?).to be true
      end
      str_plus_one_milli = '16:04:31.459 PDT Thu Aug 6 2015'
      it "is earlier than \"#{str_plus_one_milli}\"" do
        expect(time).to be < ASAConsole::Util.parse_cisco_time(str_plus_one_milli)
      end
    end

    str = '18:55:05.551 GMT/BDT Mon May 11 2015'
    context "result from parsing #{str.dump}" do
      time = ASAConsole::Util.parse_cisco_time(str)
      it 'is a Time object' do
        expect(time).to be_a Time
      end
      it 'has the correct year, month and day' do
        expect(time.year).to eq 2015
        expect(time.month).to eq 5
        expect(time.day).to eq 11
      end
      it 'has the correct hour, minute and second' do
        expect(time.hour).to eq 18
        expect(time.min).to eq 55
        expect(time.sec).to eq 5
      end
      it 'has the correct subseconds' do
        expect(time.subsec).to eq 0.551
      end
      it 'is a Monday' do
        expect(time.monday?).to be true
      end
      str_plus_one_milli = '18:55:05.552 GMT/BDT Mon May 11 2015'
      it "is earlier than \"#{str_plus_one_milli}\"" do
        expect(time).to be < ASAConsole::Util.parse_cisco_time(str_plus_one_milli)
      end
    end

    str = "Configuration last modified by enable_1 at 16:23:03.599 EDT Fri Jul 17 2015\n"
    context "result from parsing #{str.dump}" do
      time = ASAConsole::Util.parse_cisco_time(str)
      it 'is a Time object' do
        expect(time).to be_a Time
      end
      it 'is 16:23 on a Friday' do
        expect(time.hour).to eq 16
        expect(time.min).to eq 23
        expect(time.friday?).to be true
      end
    end

    str = "Last Failover at: 21:08:43 EST Jan 3 2015\n"
    context "result from parsing #{str.dump}" do
      time = ASAConsole::Util.parse_cisco_time(str)
      it 'is a Time object' do
        expect(time).to be_a Time
      end
      iso8601 = '2015-01-03 21:08:43'
      it "evaluates to #{iso8601.dump}" do
        expect(time.strftime('%F %T')).to eq iso8601
      end
    end

    context 'with a block given' do
      before :context do
        @expected_result = Time.now
        @result = ASAConsole::Util.parse_cisco_time('22:50:27.287 UTC Sun Jun 28 2015') do |t, tz|
          @time = t
          @timezone = tz
          @expected_result
        end
      end
      it 'yields a time and a timezone string' do
        expect(@time).to be_a Time
        expect(@timezone).to eq 'UTC'
      end
      it 'returns the result from evaluating the block' do
        expect(@result).to eq @expected_result
      end
    end

  end

  context '::version_match?' do
    before :context do
      @version = '8.2(1)'
    end
    it 'will return true when all expressions match' do
      result = ASAConsole::Util.version_match? @version, [ '8.x', '8.2', '<8.3' ]
      expect(result).to be true
    end
    it 'will return false when any of the expressions do not match' do
      result = ASAConsole::Util.version_match? @version, [ '8.2(1)', '8.2', '>8' ]
      expect(result).to be false
    end
  end

  context '::version_match_parse' do
    valid_expressions = {
      '7'         => { opr: '==', pattern: [7] },
      '7.x'       => { opr: '==', pattern: [7] },
      '7.2'       => { opr: '==', pattern: [7, 2] },
      '7.2(x)'    => { opr: '==', pattern: [7, 2] },
      '7.2(2)'    => { opr: '==', pattern: [7, 2, 2] },
      '>7.2(2)'   => { opr: '>',  pattern: [7, 2, 2] },
      '>=7.2(2)'  => { opr: '>=', pattern: [7, 2, 2] },
      '<7.2(2)'   => { opr: '<',  pattern: [7, 2, 2] },
      '<=7.2(2)'  => { opr: '<=', pattern: [7, 2, 2] },
      '!7.2(2)'   => { opr: '!=', pattern: [7, 2, 2] },
      '!=7.2(2)'  => { opr: '!=', pattern: [7, 2, 2] },
      '=7.2(2)'   => { opr: '==', pattern: [7, 2, 2] },
      '==7.2(2)'  => { opr: '==', pattern: [7, 2, 2] }
    }
    invalid_expressions = [
      '7.2.2',
      '7.2.x',
      '7.x.x'
    ]
    valid_expressions.each do |expr, expected_result|
      it "correctly parses #{expr.dump}" do
        ASAConsole::Util.version_match_parse(expr) do |opr, pattern|
          expect(opr).to eq expected_result[:opr]
          expect(pattern).to eq expected_result[:pattern]
        end
      end
    end
    invalid_expressions.each do |e|
      it "raises Error::InvalidExpressionError for expression #{e.dump}" do
        expect do
          ASAConsole::Util.version_match_parse(e)
        end.to raise_error ASAConsole::Error::InvalidExpressionError
      end
    end
  end

  context '::version_match_compare' do
    ver = [ 1, 0, 1 ]
    patterns = [ [ 1 ], [ 1, 0 ], [ 1, 0, 1 ] ]
    patterns.each do |pattern|
      it "correctly compares #{ver} with #{pattern}" do
        expect(ASAConsole::Util.version_match_compare('>',  ver, pattern)).to be false
        expect(ASAConsole::Util.version_match_compare('>=', ver, pattern)).to be true
        expect(ASAConsole::Util.version_match_compare('<',  ver, pattern)).to be false
        expect(ASAConsole::Util.version_match_compare('<=', ver, pattern)).to be true
        expect(ASAConsole::Util.version_match_compare('!=', ver, pattern)).to be false
        expect(ASAConsole::Util.version_match_compare('==', ver, pattern)).to be true
      end
    end
  end

end
