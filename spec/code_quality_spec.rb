# frozen_string_literal: true

# Code-quality guard. Prevents regressions of the forbidden patterns
# documented in TODO.work/02 and the global CLAUDE.md:
#
#   - .send(:private_method) — bypasses encapsulation
#   - instance_variable_set / instance_variable_get — same
#   - respond_to?(...) — duck-typing that hides type errors
#   - require_relative "..." — eager-loads, breaks load path
#   - require "opencdd/..." — same
#
# The generated racc parser (lib/opencdd/cddal/generated_parser.rb) is
# exempt because it is machine-generated from lib/opencdd/cddal/cddal.y.
# Fix the grammar source and regenerate; do not hand-edit the parser.

RSpec.describe "code quality" do
  let(:library_sources) do
    Dir.glob("lib/**/*.rb").reject do |f|
      f.end_with?("/generated_parser.rb")
    end
  end

  def grep(pattern)
    library_sources.each_with_object([]) do |file, hits|
      File.readlines(file).each_with_index do |line, idx|
        hits << "#{file}:#{idx + 1}: #{line.strip}" if line.match?(pattern)
      end
    end
  end

  it "does not use .send (use public_send for dynamic dispatch to public API)" do
    # `.send` bypasses Ruby's privacy check. Even when the target
    # method is public today, a `.send` call site is a privacy
    # violation waiting to happen (move the method to private and
    # the .send call still works, hiding the bug).
    #
    # Allowed alternatives:
    #   - public_send for dynamic dispatch to a public method
    #   - instance_exec(&block) for DSLs that need private helpers
    #   - explicit method definition when the dispatch set is small
    hits = grep(/[^_a-zA-Z]send\(/)
    expect(hits).to be_empty,
      ".send found — use public_send or instance_exec (TODO.work/02):\n#{hits.join("\n")}"
  end

  it "does not use instance_variable_set / instance_variable_get" do
    hits = grep(/instance_variable_(set|get)\b/)
    expect(hits).to be_empty,
      "instance_variable_set/get found — breaks encapsulation:\n#{hits.join("\n")}"
  end

  it "does not use respond_to? for type checks" do
    hits = grep(/\.respond_to\?\(/)
    expect(hits).to be_empty,
      "respond_to? found — use is_a? or design the hierarchy (TODO.work/02):\n#{hits.join("\n")}"
  end

  it "does not use require_relative" do
    hits = grep(/^\s*require_relative\s/)
    expect(hits).to be_empty,
      "require_relative found — use autoload in the parent namespace (TODO.work/01):\n#{hits.join("\n")}"
  end

  it "does not use require for internal cdd paths" do
    hits = grep(/^\s*require\s+["']cdd\//)
    expect(hits).to be_empty,
      "internal require found — use autoload in the parent namespace (TODO.work/01):\n#{hits.join("\n")}"
  end
end
