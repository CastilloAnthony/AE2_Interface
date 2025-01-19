--[[
  Developed by Anthony Castillo 6/27/2023
  (WIP)  
]]--
-- Diffie–Hellman key exchange

crypt = {}

function crypt.prime(n)
    for i = 2, n^(1/2) do
        if (n % i) == 0 then
            return false
        end
    end
    return true
end --end prime

function crypt.gcd(a, b)
    while b ~= 0 do
        a, b = b, a % b
    end
    return a
end --end gcd

function crypt.modExp(a, b, mod)
    local result = 1
    a = a % mod
    while b > 0 do
        if b % 2 == 1 then
            result = (result * a) % mod
        end
        b = math.floor(b / 2)
        a = (a * a) % mod
    end
    return result
end --end modExp

function crypt.isPrimitiveRoot(g, n, phi, factors)
    for _, factor in ipairs(factors) do
        if crypt.modExp(g, math.floor(phi / factor), n) == 1 then
            return false
        end
    end
    return true
end --end isPrimitiveRoot

function crypt.primeFactors(n)
    local factors = {}
    local divisor = 2
    while n > 1 do
        if n % divisor == 0 then
            factors[#factors + 1] = divisor
            while n % divisor == 0 do
                n = math.floor(n / divisor)
            end
        end
        divisor = divisor + 1
        if divisor * divisor > n then
            if n > 1 then
                factors[#factors + 1] = n
            end
            break
        end
    end
    return factors
end --end primeFactors

function crypt.eulerTotient(n)
    local result = n
    local factors = crypt.primeFactors(n)
    for _, factor in ipairs(factors) do
        result = math.floor(result * (factor - 1) / factor)
    end
    return result
end --end eulerTotient

function crypt.findPrimitiveRoots(n)
    local phi = crypt.eulerTotient(n)
    local factors = crypt.primeFactors(phi)
    local roots = {}
    for g = 2, n - 1 do
        if crypt.gcd(g, n) == 1 and crypt.isPrimitiveRoot(g, n, phi, factors) then
            roots[#roots + 1] = g
            os.sleep(0)
        end
    end
    return roots
end --end findPrimitiveRoots

function crypt.generateParameters(min, max) -- 1000, 10000
    while true do
        local n = math.random(min, max)
        os.sleep(0)
        if crypt.prime(n) then
            local primitiveRoots = crypt.findPrimitiveRoots(n)
            if #primitiveRoots > 0 then
                local temp = math.random(1, #primitiveRoots)
                return n, primitiveRoots[temp]
            end
        end
    end
end --end generateParameters

function crypt.generatePrivatePublicKeys(p, g, min, max)
    local key = 4
    while not crypt.prime(key) do
        local temp = math.random(min, max)
        if crypt.prime(temp) then
            os.sleep(0)
            if crypt.modExp(g, temp, p) > 3 then
                key = temp
            end
        end
    end
    return key, crypt.modExp(g, key, p)
end --end generatePrivatePublicKeys

function crypt.generateSharedKey(private, public, p)
    return crypt.modExp(public, private, p)
end --end generateSharedKey

function crypt.encrypt(sharedKey, payload)
    local payloadLength = #payload
    local encryption = {}
    for i = 1, payloadLength do
        encryption[i] = sharedKey * string.byte(payload, i)
    end
    return table.concat(encryption, ' ')
end --end encrypt

function crypt.decrypt(sharedKey, payload)
    local decryption = {}
    for chunk in string.gmatch(payload, "%S+") do
        decryption[#decryption + 1] = string.char(tonumber(chunk) / sharedKey)
    end
    return table.concat(decryption)
end --end decrypt

return crypt