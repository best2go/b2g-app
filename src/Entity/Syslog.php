<?php

declare(strict_types=1);

namespace App\Entity;

use App\Entity\Traits\CreatedAtAwareEntity;
use App\Entity\Traits\IdAwareEntity;
use App\Entity\Traits\XRequestIdAwareEntity;
use DateTime;
use Doctrine\ORM\Mapping as ORM;

/**
 * @ORM\Entity()
 */
class Syslog
{
    use IdAwareEntity;
    use CreatedAtAwareEntity;
    use XRequestIdAwareEntity;

    /**
     * @var string
     * @ORM\Column(name="facility", type="string", length=16, nullable=false, columnDefinition="DEFAULT 'kernel'")
     */
    private $facility;

    /**
     * @var string
     * @ORM\Column(name="level", type="string", length=16, nullable=false)
     */
    private $level;

    /**
     * @var string
     * @ORM\Column(name="message", type="string", length=256, nullable=false)
     */
    private $message;

    /**
     * @var array
     * @ORM\Column(name="context", type="json", nullable=true)
     */
    private $context = [];

    /**
     * @var string|null
     * @ORM\Column(name="hostname", type="string", length=32, nullable=true)
     */
    private $hostname;

    /**
     * @var string|null
     * @ORM\Column(name="env", type="string", length=16, nullable=true)
     */
    private $env;

    public function __construct()
    {
        $this->setCreatedAt(new DateTime());
        $this->setHostname($_SERVER['HOSTNAME'] ?? null);
        $this->setEnv($_ENV['APP_ENV'] ?? null);
    }

    public function setFacility(string $facility): void
    {
        $this->facility = $facility;
    }

    public function getFacility(): string
    {
        return $this->facility;
    }

    public function setLevel(string $level): void
    {
        $this->level = $level;
    }

    public function getLevel(): ?string
    {
        return $this->level;
    }

    public function setMessage(string $message): void
    {
        $this->message = $message;
    }

    public function getMessage(): string
    {
        return $this->message;
    }

    public function merge(array $context): void
    {
        $this->context = array_merge($this->context, $context);
    }

    public function get(string $key)
    {
        return $this->context[$key] ?? null;
    }

    public function getContext(): array
    {
        return $this->context;
    }

    public function setHostname(?string $hostname): void
    {
        $this->hostname = $hostname;
    }

    public function getHostname(): ?string
    {
        return $this->hostname;
    }

    public function setEnv(?string $env): void
    {
        $this->env = $env;
    }

    public function getEnv(): ?string
    {
        return $this->env;
    }
}
