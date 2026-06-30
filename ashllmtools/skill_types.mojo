"""skill_types — shared SkillResult and Skill types for the skill system."""


struct SkillResult(Copyable, ImplicitlyCopyable, Movable, ImplicitlyDeletable):
    """Result returned by every skill. ok=False + reason = failure."""
    var ok:     Bool
    var output: String
    var reason: String

    def __init__(out self, ok: Bool, output: String, reason: String = ""):
        self.ok     = ok
        self.output = output
        self.reason = reason

    @staticmethod
    def success(output: String) -> SkillResult:
        return SkillResult(True, output, "")

    @staticmethod
    def failure(reason: String) -> SkillResult:
        return SkillResult(False, "", reason)


struct Skill(Copyable, ImplicitlyCopyable, Movable, ImplicitlyDeletable):
    """Metadata for a registered skill discovered from skills/<cat>/<name>.md."""
    var name:     String
    var desc:     String
    var category: String

    def __init__(out self, name: String, desc: String, category: String):
        self.name     = name
        self.desc     = desc
        self.category = category
