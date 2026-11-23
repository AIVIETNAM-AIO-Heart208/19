struct AssociationRule
    antecedent::Tuple{Vararg{Int}}
    consequent::Tuple{Vararg{Int}}
    joint_count::Int
    antecedent_count::Int
    consequent_count::Int
    baskets::Int
end

rule_support(rule::AssociationRule) = rule.joint_count // rule.baskets
rule_confidence(rule::AssociationRule) = rule.joint_count // rule.antecedent_count
rule_lift(rule::AssociationRule) = widemul(rule.joint_count, rule.baskets) //
                                  widemul(rule.antecedent_count, rule.consequent_count)

function collect_rules!(rules, counts, items, index, left, right, joint, baskets, minconf)
    if index > length(items)
        (isempty(left) || isempty(right)) && return
        antecedent, consequent = Tuple(left), Tuple(right)
        left_count = counts[antecedent]
        joint // left_count >= minconf || return
        push!(rules, AssociationRule(antecedent, consequent, joint, left_count,
                                     counts[consequent], baskets))
        return
    end
    push!(left, items[index])
    collect_rules!(rules, counts, items, index + 1, left, right, joint, baskets, minconf)
    pop!(left)
    push!(right, items[index])
    collect_rules!(rules, counts, items, index + 1, left, right, joint, baskets, minconf)
    pop!(right)
    return
end

"""Rank rules from the complete frequent itemsets returned by Eclat."""
function association_rules(itemsets, baskets::Int, minconf::Rational)
    baskets > 0 || throw(ArgumentError("At least one basket is required"))
    0 <= minconf <= 1 || throw(ArgumentError("Confidence threshold must be in [0, 1]"))
    counts = Dict{Tuple{Vararg{Int}},Int}(Tuple(items) => count for (items, count) in itemsets)
    rules = AssociationRule[]
    left, right = Int[], Int[]
    for (items, joint) in itemsets
        length(items) >= 2 || continue
        collect_rules!(rules, counts, items, 1, left, right, joint, baskets, minconf)
    end
    sort!(rules; by=rule -> (-rule_lift(rule), -rule_confidence(rule), -rule.joint_count,
                            rule.antecedent, rule.consequent))
    return rules
end
